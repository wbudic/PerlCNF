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
       my $sql = $cnf->SQL(); 
      $test->isDefined("\$sql",$sql);
      $test->case("Passed new instance CNFSQL");

      $test->case("Parse CNF into SQL.");
      $cnf->parse(undef,q(
         <<MyTable<TABLE>
            name  varchar(20) NOTNULL
         >>
      ));
      $sql->addStatement('selAll','select * from MyTable;');




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