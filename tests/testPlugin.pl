#!/usr/bin/env perl
use warnings; use strict;
use Syntax::Keyword::Try;

use lib "tests";
use lib "system/modules";
use Date::Manip;

require TestManager;
require CNFParser;

my $test = TestManager -> new($0);
my $cnf;

try{
    ###
    # Test instance creation.
    #
    die $test->failed() if not $cnf = CNFParser->new('./old/pluginTest.cnf',{DO_ENABLED=>1});
    $test->case("Passed new instance CNFParser for:".$cnf->{CNF_CONTENT});
    #
    #$test-> nextCase();
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