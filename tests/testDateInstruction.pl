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
    #
    die $test->failed() if not $cnf = CNFParser->new(undef,{TZ=>"Australia/Sydney"});
    $test->case("Test Date.");
    $cnf->parse(undef,q(<<today<DATE>>>));
    my $today = $cnf->anon('today');
    $test->isDefined('$today',$today);
    $cnf->parse(undef,q(<<relasedate<DATE>2018-11-28>>));
    my $reldat = $cnf->anon('relasedate');
    $test->isDefined('$reldat',$reldat);
    $test->evaluate("Is DateTime object?",'DateTime',ref($reldat));
    $test->evaluate("relasedate year is 2018?",$reldat->year(),2018);
    $test->evaluate("relasedate month is 11?",$reldat->month(),11);
    $test->evaluate("relasedate year is 28?",$reldat->day(),28);
    $test->passed("Assigned date properly->$reldat");


    $cnf->parse(undef,q(<<date_and_time<DATE>01/12/2000 5:30 am>>));
    my $DandT = $cnf->anon('date_and_time');
    $test->isDefined('$DandT',$DandT);    
    $test->evaluate("Is Scalar object, and such invalid?",'SCALAR',ref($DandT));

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