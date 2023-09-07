#!/usr/bin/env perl
use warnings; use strict;
use Syntax::Keyword::Try;
use Benchmark;
use lib "tests";
use lib "system/modules";

require TestManager;
require CNFParser;

my $test = TestManager -> new($0);
my $cnf;

try{

   die $test->failed() if not $cnf = CNFParser->new();
       $test->case("Passed new instance CNFParser.");
       $test->subcase('CNFParser->VERSION is '.CNFParser->VERSION);
   my  $sql = $cnf->SQL();
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
   $test->nextCase();
   #

   ###
   $test->case("Test local SQL Database Setup.");
   `rm -f test_db_central.db`;
   #
   my $t0 = Benchmark->new;
   die $test->failed() if not $cnf = CNFParser->new('tests/dbSQLSetup.cnf',{DO_ENABLED=>1,DEBUG=>1});
   my $t1 = Benchmark->new;
    my $td = timediff($t1, $t0);
    print "The CNF translation for tests/dbSQLSetup.cnf took:",timestr($td),"\n";
   $sql = $cnf->SQL();

    #
    #
    $test->done();
    #
}
catch{
   $test -> dumpTermination($@);
   $test -> doneFailed();
}
