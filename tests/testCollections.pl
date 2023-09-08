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
   ###
   die $test->failed() if not $cnf = CNFParser->new();
       $test->case("Passed new instance CNFParser.");
       $test->subcase('CNFParser->VERSION is '.CNFParser->VERSION);

   #



    ###
    # Test hsh instance creation.
    ###
    $test->case("Test hsh property.");
    $cnf ->parse(undef,q(<<@<%list>
                                            a=1
                                            b= 2
    >>
    ));
    $test->subcase('Contains %list property.');
    my %list = $cnf ->property('%list');
    die $test->failed() if not %list;
    $test->evaluate('%list contains a=1',$list{'a'},1);
    $test->evaluate('%list contains b=2',$list{'b'},2);
    my $format = q(<<@<%list>c=3>>);
    $test->subcase("Parse format $format");
    $cnf ->parse(undef,$format);
    %list = $cnf ->property('%list');
    $test->evaluate('%list contains c=3',$list{'c'},3);

    $format = q(<<@<%list>d=4>>);
    $test->subcase("Parse format $format");
    $cnf ->parse(undef,$format);
    %list = $cnf ->property('%list');
    $test->evaluate('%list contains d=4',$list{'d'},4);
    #

    ###
    # Test array instance creation.
    # $test->case("Test hsh property.");
    $test->case('Test @array property.');
    $cnf ->parse(undef,q(<<@<@array>
         1,2
         3,4
    >>
    ));
    my @array = $cnf ->property('@array');
    #Important -> In perl array type is auto exanded into arguments.
    # Hence into scalar result we want to pass.
    $test->evaluate('@array contains 4 elements?', scalar(@array), 4);
    $test->evaluate('@array[0]==1', $array[0],1);
    $test->evaluate('@array[-1]==4',$array[-1],4);

    $test->case("Old PerlCNF property format.");
     $cnf ->parse(undef, q(<<@<@config_files<
file1.cnf
file2.cnf
>>>));
@array = $cnf ->property('@config_files');
$test->evaluate('@array contains 2 elements?', scalar( @array ), 2);
$test->evaluate('@array last element is file2.cnf?', pop @array , 'file2.cnf');

   #


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