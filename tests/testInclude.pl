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
    die $test->failed() if not $cnf = CNFParser->new('tests/include.cnf',{STRICT=>0});
    $test->case("Passed new instance CNFParser for:".$cnf->{CNF_CONTENT});
    #  
    $test-> nextCase();
    #   
    my $dbg_level = $cnf->{'$DEBUG_LEVEL'};
    $test->evaluate("Is \$DEBUG_LEVEL still 1, as set in script and a constance?",$dbg_level,1);
    $test->evaluate("Is anon ME_TOO is overwritten by example.cnf to [1024]?",$cnf->anon('ME_TOO'),1024);

    #   
    $test->done();    
    #
}
catch { 
   $test -> dumpTermination($@);   
   $test -> doneFailed();
}

#
#  TESTING THE FOLLOWING IS FROM HERE  #
#