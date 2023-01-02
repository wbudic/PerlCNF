#!/usr/bin/env perl
use warnings; use strict; 
use lib "./tests";
use lib "/home/will/dev/ServerConfigCentral/local";

require TestManager;
require CNFParser;
require CNFNode;

my $test = TestManager->new($0);

use Syntax::Keyword::Try; try {

    ###
    # Test instance creation.
    ###
    die $test->failed()  if not my $node = CNFNode->new({'_'=>'node','#'=>1});
    $test->evaluate("name==node",$node->name(),'node');
    $test->evaluate("val==1",$node->val(),1);
    $test->case("Passed new instance for CNFParser.");
    #
    #  
    $test-> nextCase();
    #

    ###
    # Test validation.
    ###
    $test->case("Testing validation.");

    $test->subcase('Misslosed property.');

    my $errors = $node -> validate(qq(
        [a[
            [b[
                <e<
                [#[some value]#]
            ]b]
            >e>
        ]a]

    ));

    $test->subcase('Unclosed property.');

   $node -> validate(qq(
        [a[
            [b[
                <e<
                [#[some value]#]
            ]b]            
        ]a]
        ]c]

    )); 

    #
    $test-> nextCase();
    #

    

    #
    $test->done();
    #
}
catch{ 
   $test -> dumpTermination($@);   
   $test->doneFailed();
}


