#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;

use lib "tests";
use lib "system/modules";

require TestManager;
require CNFParser;
require ExtensionSamplePlugin;

my $test = TestManager -> new($0);
my $cnf;

my $plugin = ExtensionSamplePlugin->new();

try{
    ###
    # Test instance creation.
    #    
    die $test->failed() if not $cnf = CNFParser->new('./tests/extensions.cnf',{DO_ENABLED=>1,HAS_EXTENSIONS=>1});
    $test->case("Passed new instance CNFParser for:".$cnf->{CNF_CONTENT});
    #  
    $test-> nextCase();
    #   

    my %data = %{$cnf->data()};
    $test->evaluate("Data hash has two keys?", scalar keys %data, 2);

    my @table = values %data;
    $test->evaluate("First table has 28 entries?", scalar(@{$table[0]}), 28);
    $test->evaluate("Second table has 28 entries?", scalar(@{$table[1]}), 28);
    $test->evaluate("Second table has 9 as first value?", @{$table[2]}[0], 9);
    $test ->isDefined("\$SOME_CONSTANCE",$cnf->{'$SOME_CONSTANCE'});


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