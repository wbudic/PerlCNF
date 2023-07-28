#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;

use lib "tests";
use lib "system/modules";

require TestManager;
require CNFParser;

use Math::Cartesian::Product;

my $test = TestManager -> new($0);
my $cnf;

try{
    
    
    $test->case("Test Cartesian Product lib.");
    my @colors      = ["red","blue","green"];
    my @sizes       = ["small","medium","large"];
    my @materials   = ["cotton","wool","silk"];
    my @res = cartesian {$test->isDefined("Product: [@_] ",@_)} @colors, @sizes, @materials;

    $test->evaluate("Result has ".(3*3*3)." combinations?",27,scalar @res);

    #  
    $test-> nextCase();
    #

    $test->case("Test via map removal.");
    my $links = [
        "www.ibm.com",
        "     www.x.com     ",
        "www.google.me   "
    ];
    ##no critic ControlStructures::ProhibitMutatingListFunctions
    my @copy = @$links;
    map {s/^\s+|\s+$//g;s/^www\.//i;$_} @copy;

    $test->evaluate("Copy has 3 links?",scalar @copy,3);
    $test->evaluate("Copy item 1 is trmmed?","ibm.com",$copy[0]);
    $test->evaluate("Copy item 2 is trmmed?","x.com",$copy[1]);

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