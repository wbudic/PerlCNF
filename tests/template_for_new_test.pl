#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;
use lib "./system/modules";

require TestManager;
my $test = TestManager -> new($0);
my $cnf;

try{
    ###
    # Test instance creation.
    #
    die $test->failed() if not $cnf = CNFParser->new();
    $test->case("Passed new instance CNFParser.");
    #  
    $test-> nextCase();
    #   

    #   
    $test->done();    
    #
}
catch{ 
   $test -> dumpTermination($@);   
   $test -> doneFailed();
}

#
#  TESTING THE FOLLOWING IS FROM HERE  #
#