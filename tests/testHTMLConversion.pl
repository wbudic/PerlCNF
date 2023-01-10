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
<<test<TREE>
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
    my $plugin = HTMLProcessorPlugin -> new() -> convert($parser, 'test');
    my $html = $parser->data()->{'test'};
    my $tree = $parser->anon('test');
    die 'Not defined $tree' if !$tree;
    my $images = $tree->find('list_images');
    my $arr  = $images->{'@@'};
    die "Not expected size!" if @$arr != 2;

    
    #
    $test->done();
    #
}
catch{ 
   $test -> dumpTermination($@);
   $test->doneFailed();
}


    