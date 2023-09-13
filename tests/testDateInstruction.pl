#!/usr/bin/env perl
use warnings; use strict;
use Syntax::Keyword::Try;

use lib "tests";
use lib "/home/will/dev/PerlCNF/system/modules";


require TestManager;
require CNFDateTime;
require CNFParser;

my $test = TestManager -> new($0);
my $cnf;


try{
    $test->case("Test TZ settings.");
        $test->subcase("Test list availabe countries.");
        my @countries =  CNFDateTime::_listAvailableCountryCodes();
        $test->evaluate("Is country list avalable?", scalar @countries, 248);
        my $random_country_code = $countries[int(rand(scalar(@countries)))];
        $test->passed("Picked random country -> ".uc $random_country_code);

        $test->subcase("Test list availabe cities in Europe?");
        my @cities =  CNFDateTime::_listAvailableTZ('Europe');
        $test->evaluate("Is cities list avalable?", scalar @cities, 38);
        my $random_city_in_eu = $cities[int(rand(scalar(@cities)))];
        $test->passed("Picked random city in eu -> ".uc $random_city_in_eu);

        my @cities_of_random =  CNFDateTime::_listAvailableTZ($random_country_code);
        my $random_city_in_picked = $cities_of_random[int(rand(scalar(@cities_of_random)))];
        $test->passed("Picked random city in $random_country_code -> ".uc $random_city_in_picked);


    #
    $test->case("Test CNFDateTime Instance.");
    die $test->failed() if not my $loca = CNFDateTime -> new(); # <- TODO This will use the default locale as US not the system one, I don't know why yet<moth?
    die $test->failed() if not my $date = CNFDateTime -> new(TZ=>$random_city_in_picked);
    my $datetime = $date -> datetime();
    $test->isDefined('$datetime',$datetime);
    $test->passed("For $random_city_in_picked time was set ->".$date -> toSchlong() );
    my $your_locale_date  = $loca->datetime();
    my $locale = $your_locale_date->locale();
    $test->passed("For ".$locale->{code}." time was set ->".$loca -> toSchlong() );



    $test->nextCase();
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

    $test->case("Invalid date format, long, but could be parsable and passable.");
    $cnf ->parse(undef,q(<<date_and_time<DATE>01/12/2000 5:30 am>>));#-> Wrong--. Actually for any
    my $DandT = $cnf->anon('date_and_time');                                  # | other country
    $test->isDefined('$DandT',$DandT);                                        # | then the US.
    $test->evaluate("Is CNFDateTime object?",'CNFDateTime',ref($DandT));      # |
    $test->evaluate("Is in us format parsed date?",'2000-01-12 05:30:00.000 AEDT',#<-.
           $DandT->toTimestamp());

    $test->case("Test now and today!");
    $cnf->parse(undef,q(
        <<date_now<DATE<now>>>
        <<date_today<DATE>Today>>
    ));
    my $dtNow = $cnf->anon('date_now');
    my $dtToday = $cnf->anon('date_today');
    $test->isDefined('$dtNow',$dtNow);
    $test->isDefined('$dtToday',$dtToday);
    $test->passed("Today assignment test run \@:".$dtToday->toTimestamp());
####
## Disable this test case (comment out) if your OS or Perl failed here.
## Logging itself, is not crucial for Perl CNF, never was.
## Realtime logging in nanoseconds, yes this test is checking.
####
    $test->case("Check if logging is displaying proper nano output.");
    my $t1 = $cnf->log("Check1");
    my $t2 = $cnf->log("Check2");
    my $t3 = $cnf->log("Check2");
    $t1 =~ /\d\d\d\d-\d+-\d+\s\d+:\d+:\d+\.(\d\d\d)/; $t1 = $1;
    $t2 =~ /\d\d\d\d-\d+-\d+\s\d+:\d+:\d+\.(\d\d\d)/; $t2 = $1;
    $t3 =~ /\d\d\d\d-\d+-\d+\s\d+:\d+:\d+\.(\d\d\d)/; $t3 = $1;
     if($t1 ne '000' && $t1!=$t2 && $t2 != $t3){
        $test -> passed("Nano logging is working!")
     }else{
        $test -> failed("Nano sec. for logging failed! Eh?->$t1$t2$t3")
     }

    $test->case("Test Date Formats");
    $date = $cnf->now();
    $test->subcase(&CNFDateTime::FORMAT);
    $test -> passed($date->datetime() -> strftime(&CNFDateTime::FORMAT));
    $test->subcase(&CNFDateTime::FORMAT_NANO);
    $test -> passed($date->datetime() -> strftime(&CNFDateTime::FORMAT_NANO));
    $test->subcase(&CNFDateTime::FORMAT_SCHLONG);
    $test -> passed($date->datetime() -> strftime(&CNFDateTime::FORMAT_SCHLONG));
    $test->subcase(&CNFDateTime::FORMAT_MEDIUM);
    $test -> passed($date->datetime() -> strftime(&CNFDateTime::FORMAT_MEDIUM));


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