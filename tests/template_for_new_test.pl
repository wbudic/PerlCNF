#!/usr/bin/env perl
use warnings; use strict; 
use lib "./tests";
use lib "./local";

require TestManager;
require CNFCentral;
use Syntax::Keyword::Try;


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