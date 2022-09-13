#!/usr/bin/env perl
use warnings; use strict; 

use lib "./tests";
use lib "./system/modules";

require TestManager;
require CNFParser;

use Syntax::Keyword::Try;


my $test = TestManager -> new($0);
my $cnf;

try{
    ###
    # Test instance creation.
    ###
    die $test->failed() if not $cnf = CNFParser->new();
    $test->case("Passed new instance CNFParser.");    
    #  
    $test-> nextCase();
    #   
    $test->case("Check cnf list specified type properties."); 
    my $exp = q|<<data$$<a=1>_some_value_>>|;
       $cnf->parse(undef,$exp);
    my @aitms = $cnf->list('data');
    my %item = %{$aitms[0]};
    $test->subcase(q!cnf -> list('data')->id:!.$item{'aid'}.'<'.$item{'ins'}.'><'.$item{'val'}.'>', "\n");
    $test->evaluate('0', $item{'aid'});
    $test->evaluate('a=1', $item{'ins'});
    $test->evaluate('_some_value_', $item{'val'});
    #

+    my $hasFailures = $test->nextCase(); die $hasFailures if $hasFailures;
    #

    ###
    $test->case("Check DATA instruction dnamically");
    $cnf->parse(undef,qq(<<my\$\$<DATA>01`This comes from Cabramatta~\n>>));
    $test->subcase("Contain 'my\$\$' as 'my' data property?");
    my @data = @{%{$cnf->data()}{'my'}};
    my @mydt = @{$data[0]};
    $test->evaluate(\@mydt);    
    $test->evaluate('01',$mydt[0]);
    ###
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