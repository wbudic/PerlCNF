#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;

use lib "tests";
use lib "system/modules";

require TestManager;
require CNFParser;

my $test = TestManager -> new($0);
my $cnf;


try{
    die $test->failed() if not my $cnf = CNFParser->new(undef,{'%LOG'=>{console=>1}});
        $test->case('Passed CNFParser->new().');
        $test->case("Parse Typical Processor registration.");
        my $processor = $cnf->registerProcessor("TestInstructor",'process');
        $test->isDefined("\$processor", $processor);
     $test -> nextCase();
        $test->case("Test parsing registration.");
        $cnf->parse(undef,q(
            <<TestInstructor<PROCESSOR>function:process>>
        ));
      $test -> nextCase();        

    #   
    $test -> done();
    #
}
catch{ 
   $test -> dumpTermination($@);   
   $test -> doneFailed();
}

#
#  TESTING THE FOLLOWING IS FROM HERE  #
#