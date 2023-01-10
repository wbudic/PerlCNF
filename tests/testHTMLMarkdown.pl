use warnings; use strict;
#use 5.36.0;
use lib "/home/will/dev/ServerConfigCentral/local";
use lib "tests";


require TestManager;
require CNFParser;
require MarkdownPlugin;


my $test = TestManager -> new($0);

use Syntax::Keyword::Try; try {   


  

    ###
    $test->case("Markdown Instance");
    my $plugin = MarkdownPlugin->new();


    $test->case("Test ordered lists");   
    my $doc = $plugin->parse(qq(
        <b><https://duckduckgo.com></b>
        **Links** [Duck Duck Go](https://duckduckgo.com)
    ));
    
    my $txt = @{$doc}[0];

    $test->case("Markdown Parser");
     $doc = $plugin->parse(qq(
        # Hello
        You *fool*
        listening to **politics**!
        ***
    ));
    $txt = ${@{$doc}[0]};
    ($txt =~ /(<h1>.*<\/h1>)/);
     my $t = $1;
     $test->evaluate("Has <h1> Hello",$t,'<h1> Hello</h1>');

    # $test->nextCase();


    # $test->case("Test ordered lists");   
    # @html = $plugin->parse(qq(
    #     ## List
    #     1. First Item
    #     2. Second Item
    #         < Super duper
    #           multiline.
    #         - 1
    #         - 2
    #         - 3
    #     3. Third item with sub list.
    #         1. One
    #         2. Two
                    
    #     ***
    # ));
    # ($$html =~ /(<blockquote>)/);
    # $test->evaluate("Has <blockquote>",$1,'<blockquote>');

    # $test->case("Test image links.");   
    # $html = $plugin->parse(qq(
    #     ## List
    #     - New Map of Europe.
    #       < ![New Map of Europe](images/new_map_of_eu.jpg)
                    
    #     ***
    # ));
    # ($$html =~ /(<img>)/);
    # $test->evaluate("Has <img>",$1,'<img>');


    #
    $test->done();
    #
}
catch{ 
   $test -> dumpTermination($@);
   $test -> doneFailed();
}


    