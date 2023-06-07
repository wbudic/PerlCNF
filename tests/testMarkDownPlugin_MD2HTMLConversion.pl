use warnings; use strict;
use 5.36.0;
use lib "tests";
use lib "system/modules";

require TestManager;
require CNFParser;
require MarkdownPlugin;

my $test = TestManager -> new($0);

use Syntax::Keyword::Try; try {   

  

    ###
    $test->case("Test instances of parser and MarkDownPlugin.");
    my $parser = CNFParser -> new();
    $parser->parse(undef,qq(
        <<test<#Hello World!>>>
    ));
    my $plugin = MarkdownPlugin -> new();
       $plugin->convert($parser,'test');

    my $html = $parser->data()->{'test'};
    $test->isDefined('$html',$html);
    #dereference and trim
    $html=$$html;$html=~s/\n$//g;
    $test->evaluate('test property is valid html?',"<h1>Hello World!</h1><a name=\"1\"></a>",$html);
    #
    $test->nextCase();  
    #

    ###
    $test->case("Test CNF inlined properties.");
    my @cases = (

        ['<<<instruction var="value">>>',q(<span class='B'>&#60;&#60;&#60;</span><span class='pn'>instruction</span>&nbsp;<span class='pi'>var</span><span class='O'>=</span><span class='pv'>"value"</span></span><span class='B'>&#62;&#62;&#62;</span>)],
        ['<<<anon value>>>',q(<span class='B'>&#60;&#60;&#60;</span><span class='pn'>anon</span>&nbsp;<span class='pv'>value</span></span><span class='B'>&#62;&#62;&#62;</span>)],        
        ['<<anon<value>>',q(<span class='B'>&#60;&#60;</span><span class='pn'>anon</span><span class='B'>&#60;</span><span class='pv'>value</span></span><span class='B'>&#62;&#62;</span>)],
        ['<<anon>value>>',q(<span class='B'>&#60;&#60;</span><span class='pn'>anon</span><span class='B'>&#62;</span><span class='pv'>value</span></span><span class='B'>&#62;&#62;</span>)],
        ['<<anon<instruction>value>>',q(<span class='B'>&#60;&#60;</span><span class='pn'>anon</span><span class='B'>&#60;</span><span class='pi'>instruction</span><span class='B'>&#62</span><span class='pv'>value</span></span><span class='B'>&#62;&#62;</span>)],
        ['<<CONST value>>',q(<span class='B'>&#60;&#60;</span><span class='pi'>CONST</span>&nbsp;<span class='pv'>value</span></span><span class='B'>&#62;&#62;</span>)],
        
        
    );
#$a-><span class='B'>&#60;&#60;&#60;</span><span class='pn'>anon</span>&nbsp;<span class='pv'>value</span></span><span class='B'>&#62;&#62;&#62;</span>, 
#$b-><span class='B'>&#60;&#60;&#60;</span><span class='pn'>anon</span>&nbsp;<span class='pv'>value</span></span><span class='B'>&#62;&#62;&#62</span>

    foreach (@cases){
        my @case = @$_;
        $test->subcase($case[0]);
        $html = MarkdownPlugin::inlineCNF($case[0]);
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


    