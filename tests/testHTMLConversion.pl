use warnings; use strict;
use 5.36.0;
use lib "tests";
use lib "system/modules";

require TestManager;
require CNFParser;
require CNFNode;
require HTMLProcessorPlugin;
require ShortLink;

my $test = TestManager -> new($0);

use Syntax::Keyword::Try; try {   

  

    ###
    $test->case("Single line value");
    my $parser = CNFParser -> new();
    $parser->parse(undef,qq(
<<test1<TREE>
    [CSS[
        [@@[artifacts/main.css]@@]
        [@@[artifacts/in_vain.css]@@]
    ]CSS]

    [list_images[
        [@@[~/Pictures]@@]
        [@@[~/Pictures/desk_backgrounds]@@]
    ]list_images]

[row[        
    [cell[       
     

        <a< 
        name = bottom 
        >a>
        [span[
            [#[
                [
            ]#]
        ]span]
        <a<
            href = /
            [#[Home]#]
        >a>
        [span[
            [#[
                ] |
            ]#]
        ]span]        
    ]cell]
]row]
>>));

    my $plugin = HTMLProcessorPlugin -> new() -> convert($parser, 'test1');
    my $html = $parser->data()->{'test1'};
    my $tree = $parser->anon('test1');
    die 'Not defined $tree' if !$tree;
    my $images = $tree->find('list_images');
    my $arr  = $images->{'@@'};
    die "Not expected size!" if @$arr != 2;


    #
    $test->nextCase();  
    #

    ###
    $test->case("Link to outside property.");
    $parser->parse(undef,qq(
    <<test2<TREE>
        <*<anon_value3>*>
    >>
    <<anon_value1<REACHED 1!>>
    <<anon_value2>REACHED 2!>>
    <<<anon_value3
    REACHED 3!>>>
    ));    
    $test -> isDefined("\$parser->anon('anon_value1')",$parser->anon('anon_value1'));
    $test -> evaluate($parser->anon('anon_value1'),"REACHED 1!");
    $test -> isDefined("\$parser->anon('anon_value2')",$parser->anon('anon_value2'));
    $test -> evaluate($parser->anon('anon_value2'),"REACHED 2!");
    #do not now bark at the wrong tree from before, we reassigning tree with:
    $tree = $parser->anon('test2');
    die 'Not defined $tree2' if !$tree;    
    my $val = $tree->find('anon_value3');

    $test -> isDefined("\$tree->find('anon_value3')",$val);
    $test -> evaluate($val,"REACHED 3!");
    $test -> evaluate("Is the link value assigned to node anon_value3 value, same to the linked anon anon_value3?",
                        $val, $parser->anon('anon_value3'));
    # Note - When the rep. anon chages, it isn't physically linked to the node. Reparsing the tree, will rectify this.
    
    #
    $test->done();
    #
}
catch{ 
   $test -> dumpTermination($@);
   $test->doneFailed();
}


    