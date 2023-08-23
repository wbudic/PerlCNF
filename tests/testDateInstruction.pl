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
    $test->evaluate("Is CNFDateTime object?",'CNFDateTime',ref($reldat));
    $test->evaluate("relasedate year is 2018?",$reldat->datetime()->year(),2018);
    $test->evaluate("relasedate month is 11?",$reldat->datetime()->month(),11);
    $test->evaluate("relasedate year is 28?",$reldat->datetime()->day(),28);
    $test->passed("Assigned date properly \$reldat:".$reldat->toTimestamp());

    $test->case("Invalid date format, but could be parsable.");
    $cnf->parse(undef,q(<<date_and_time<DATE>01/12/2000 5:30 am>>));#<-DateTime sees as us format, all the en_* locale even, which is wrong.
    my $DandT = $cnf->anon('date_and_time');
    $test->isDefined('$DandT',$DandT);
    $test->evaluate("Is CNFDateTime object?",'CNFDateTime',ref($DandT));
    $test->evaluate("Is in us format parsed date?",'2000-01-12 05:30:00.000',$DandT->toTimestamp());

    $test->case("Test now and today!");
    $cnf->parse(undef,q(
        <<date_now<DATE<now>>>
        <<date_today<DATE>Today>>
    ));
    my $dtNow = $cnf->anon('date_now');
    my $dtToday = $cnf->anon('date_today');
    $test->isDefined('$dtNow',$dtNow);
    $test->isDefined('$dtToday',$dtToday);
    $test->passed("Today assignment test run @:".$dtToday->toTimestamp());
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