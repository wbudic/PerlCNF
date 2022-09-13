#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;

use lib "./tests";
use lib "./system/modules";



require TestManager;
require CNFParser;

my $test = TestManager -> new($0);
my $cnf;

try{

   ###
   # Test instance creation.
   ###
   die $test->failed() if not $cnf = CNFParser->new();
       $test->case("Passed new instance CNFParser.");
       $test->subcase('CNFParser->VERSION is '.CNFParser->VERSION);   
   

    ###
    # Test hsh instance creation.
    ###    
    $test->case("Test hsh collection.");
    $cnf ->parse(undef,q(<<@<%list>
                                            a=1
                                            b= 2
    >>    
    ));
    $test->subcase('Contains %list collection.');
    my $list = $cnf ->collection('%list');
    die $test->failed() if not $list;    
    $test->evaluate('%list contains a=1',$list->{'a'},1);
    $test->evaluate('%list contains b=2',$list->{'b'},2);
    my $format = q(<<@<%list>c=3>>);    
    $test->subcase("Parse format $format");
    $cnf ->parse(undef,$format); 
    $list = $cnf ->collection('%list');
    $test->evaluate('%list contains c=3',$list->{'c'},3);

    $format = q(<<@<%list>d=4>>);    
    $test->subcase("Parse format $format");
    $cnf ->parse(undef,$format);
    $list = $cnf ->collection('%list');
    $test->evaluate('%list contains d=4',$list->{'d'},4);
    ###
    # Test array instance creation.
    # $test->case("Test hsh collection.");
    $test->case('Test @array collection.');
    $cnf ->parse(undef,q(<<@<@array>
         1,2
         3,4
    >>
    ));
    my $array = $cnf ->collection('@array');
    $test->evaluate('@array contains 4 elements?', scalar( @$array ),4);
    $test->evaluate('@array[0]==1',@$array[0],1);
    $test->evaluate('@array[-1]==4',@$array[-1],4);
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