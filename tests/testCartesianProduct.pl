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
    my @colors  = ["red","blue","green"];
    my @sizes   = ["small","medium","large"];
    my @materials   = ["cotton","wool","silk"];
    my @res = cartesian {$test->isDefined("Product: [@_] ",@_)} @colors, @sizes, @materials;

    #  
    $test-> nextCase();
    #
    
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