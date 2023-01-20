#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;
#no critic "eval"
use lib "./tests";
use lib "./local";
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
#  TESTING ANY POSSIBLE SUBS ARE FOLLOWING FROM HERE  #
#