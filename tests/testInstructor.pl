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
    ###
    # Test instance creation.
    #
    die $test->failed() if not my $cnf = CNFParser->new(undef,{STRICT=>1});
        $test->case('Passed CNFParser->new().');
        $test->case("Parse Typical Instructor registration.");
        my $instructor = $cnf->registerInstructor("TestInstructor",'TEST');
        $test->isDefined("\$instructor", $instructor);
     $test -> nextCase();
        $test->case("Test parsing registration.");
        $cnf->parse(undef,q(
            <<TestInstructor<INSTRUCTOR>TEST2>>
        ));
     $test -> nextCase();        
        
        try{
            # New instance doesn't mask it for being global, it is still there!
            CNFParser->new(undef,{STRICT=>1})->parse(undef,q(
                <<TestInstructor<INSTRUCTOR>TEST>>
                
            ));            
            print $test->failed("Test failed! Trying to overwrite existing instruction, which are global.");
        }catch{
            $test->case("Passed fail on trying to overwrite existing instruction, which are global.");            
        }

      
    $test-> nextCase();

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