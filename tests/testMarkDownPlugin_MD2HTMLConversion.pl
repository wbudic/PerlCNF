use warnings; use strict;
use 5.36.0;
use lib "tests";
use lib "/home/will/dev/PerlCNF/system/modules/";

require TestManager;
require CNFParser;
require CNFNode;
require MarkdownPlugin;

my $test = TestManager -> new($0);

use Syntax::Keyword::Try; try {   
    ###
    $test->case("Test instances of parser and MarkDownPlugin.");
    my $parser = CNFParser -> new();
       $parser->parse(undef,qq(
            <<test<#Hello World!>>>
            <<HTML_STYLE<TREE>
                #The root of the tree is the configuration hub, containing properties and any number of content or pages.
                #Links become attributes and copies in it.
                [Content[
                    # This no more is the root from here.
                    # Following will link to a reference of a perl constant:
                    <*<MarkdownPlugin::CSS>*>
                    [#[
                        Hello World
                    ]#]
                    # Following will pass this [Content] Node  to this tests &static_test_sub.
                    <*<main::static_test_sub(.)>*>
                ]Content]
            >>>
        ));

    sub static_test_sub {
        my $node = shift;
        if($node){
           $test->passed(qq(Call to static_test_sub(.)-> Node [$node->name()] = $node->val())) 
        }else{
            print $test->faled (qq(Call to static_test_sub(.)-> called withouth passing a node))
        }
    }
    
    my $plugin = MarkdownPlugin -> new();
       $plugin->convert($parser,'test');

    my $html = $parser->data()->{'test'};
    $test->isDefined('$html',$html);
    #dereference and trim
    $html=$$html;$html=~s/\n$//g;
    $test->evaluate('test property is valid html?',$html,q(<h1>Hello World!</h1><a name="1"></a>));
    #
    $test->subcase("Check embeded link to a perl constance <*<MarkdownPlugin::CSS>*>");
    my $style = $parser->anon('HTML_STYLE');
    $test->isDefined('$style',$style);
    my @ret = $style->find('Content/MarkdownPlugin::CSS');
    my $script = $ret[0];
    if($test->isDefined('$script',$script)){
        if ($script->val() !~ m/\.B\s\{/gm){
            $test->failed("Script value doesn't contain expexted text.")
        }
    }
    #
    $test->nextCase();  
    #

    ###
    $test->case("Test CNF inlined properties.");
    my @cases = (

        ['<<<instruction var="value">>>',   q(<span class='B'>&#60;&#60;&#60;</span><span class='pa'>instruction</span></span>&nbsp;<span class='pn'>var</span><span class='O'>=</span><span class='pv'>"value"</span><span class='B'>&#62;&#62;&#62;</span>)],
        ['<<<anon value>>>',    q(<span class='B'>&#60;&#60;&#60;</span><span class='pa'>anon</span></span>&nbsp;<span class='pv'>value</span><span class='B'>&#62;&#62;&#62;</span>)],
        ['<<anon<value>>',  q(<span class='B'>&#60;&#60;</span><span class='pa'>anon</span></span><span class='B'>&#60;</span><span class='pv'>value</span></span><span class='B'>&#62;&#62;</span>)],
        ['<<anon>value>>',  q(<span class='B'>&#60;&#60;</span><span class='pa'>anon</span></span><span class='B'>&#62;</span><span class='pv'>value</span></span><span class='B'>&#62;&#62;</span>)],
        ['<<anon<instruction>value>>',  q(<span class='B'>&#60;&#60;</span><span class='pa'>anon</span></span><span class='B'>&#60;</span><span class='pv'>instruction&#62;value</span></span><span class='B'>&#62;&#62;</span>)],
        ['<<CONST value>>', q(<span class='B'>&#60;&#60;</span><span class='pi'>CONST</span></span>&nbsp;<span class='pv'>value</span><span class='B'>&#62;&#62;</span>)],
        
        
    );

#$a-><span class='B'>&#60;&#60;&#60;</span><span class='pa'>instruction</span></span>&nbsp;<span class='pn'>var</span><span class='O'>=</span><span class='pv'>"value"</span><span class='B'>&#62;&#62;&#62;</span>, 
#$b-><span class='B'>&#60;&#60;&#60;</span><span class='pn'>instruction</span>&nbsp;<span class='pi'>var</span><span class='O'>=</span><span class='pv'>"value"</span></span><span class='B'>&#62;&#62;&#62;</span>    

#$a-><span class='B'>&#60;&#60;&#60;</span><span class='pn'>instruction</span>&nbsp;<span class='pi'>var</span><span class='O'>=</span><span class='pv'>"value"</span></span><span class='B'>&#62;&#62;</span>
#$b-><span class='B'>&#60;&#60;&#60;</span><span class='pn'>instruction</span>&nbsp;<span class='pi'>var</span><span class='O'>=</span><span class='pv'>"value"</span></span><span class='B'>&#62;&#62;&#62;</span>
    foreach (@cases){
        my @case = @$_;
        $test->subcase($case[0]);
        $html = MarkdownPlugin::inlineCNF($case[0],"");
        $test->isDefined($case[0],$html);
        say $test->failed("$case[0] CNF format has not properly converted!") if $html !~ /^<span class/;
        $test->evaluate($case[0],$html,$case[1]);
    }    

    #
    $test->nextCase();  
    #
    
    #
    $test->done();
    #
}
catch{ 
   $test -> dumpTermination($@);
   $test->doneFailed();
}


    