#!/usr/bin/env perl
use warnings; use strict;

use lib "tests";
use lib "/home/will/dev/PerlCNF/system/modules";

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
    $test->case("Test standard header and DATA parsing.");
    $cnf->parse(undef,qq(
<<  Sample_Data <DATA>
ID`name`desc~
1`Mickey Mouse`Character
 owned by Disney.~
2`Olga Scheps`Pianist from Estern Europe~
    >>));
    my $sample = $cnf->data()->{Sample_Data};
    $test->isDefined('$ample',$sample);
    $test->evaluate('No. of rows is 3?', 3, scalar(@$sample));
    my @array  = @$sample;
    $test->evaluate('$array[1][2] does match?', qq(Character
owned by Disney.), $array[1][2]);
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
    $test->case("Check DATA instruction dynamically");
    $cnf->parse(undef,qq(<<my\$\$<DATA>01`This comes from Cabramatta~\n>>));
    $test->subcase("Contain 'my\$\$' as 'my' data property?");
    my @data = @{%{$cnf->data()}{'my'}};
    my @mydt = @{$data[0]};
    $test->evaluate(\@mydt);
    $test->evaluate('01',$mydt[0]);
    #
    $test-> nextCase();
    #
    $test->case("Is DATA reserved word.");
    $test->isDefined("isReservedWord('DATA')",1,$cnf->isReservedWord("DATA"));
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