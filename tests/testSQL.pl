#!/usr/bin/env perl
use warnings; use strict;
use Syntax::Keyword::Try;
use Benchmark;
use lib "tests";
use lib "system/modules";

require TestManager;
require CNFParser;
require CNFSQL;

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
            name  varchar(20) NOT NULL primary key
         >>
        ));
        $sql->addStatement('selAll','select * from MyTable;');
        $test->evaluate("Has selAll?","select * from MyTable;", $sql->getStatement('selAll'));
   #
   $test->nextCase();
   #

   ###
   $test->case("Test local SQL Database Setup.");
   `rm -f test_db_central.db`;
   #
   my $t0 = Benchmark->new;
   die $test->failed() if not $cnf = CNFParser->new('tests/dbSQLSetup.cnf',{DO_ENABLED=>1,DEBUG=>1,'%LOG'=>{console=>1}});
   my $t1 = Benchmark->new;
   my $td = timediff($t1, $t0);
   print "The CNF translation for tests/dbSQLSetup.cnf took:",timestr($td),"\n";
   my $sql2 = $cnf->SQL();
   $test->subcase("Test CNFSQL obtained.");
   $test->evaluate("Is CNFSQl ref?","CNFSQL", ref($sql2));
   #
   $test->nextCase();
   #
   $test->case("Test RSS FEEDS Plugin.");
   my $plugin = $cnf->property('PROCESS_RSS_FEEDS');
   $test->failed() if not $plugin;
   if(CNFParser::_isTrue($plugin->{CONVERT_TO_CNF_NODES})){
      $test->subcase('Test data to CNF nodes tree conversion for RSS feeds.');
      my $perl_weekly =  $cnf->getTree('Perl Weekly');
      $test->isDefined("Has tree 'Perl Weekly'?",$perl_weekly);
      my $url_node = $$perl_weekly->find("/Feed/URL");
      $test->isDefined("Has an URL defined node?",$url_node);
      $test->evaluate("CNF_FEED/Feed/URL is ok?","https://perlweekly.com/perlweekly.rss",$url_node);
   }else{
      $test->subcase('Skipped subcase tests, CONVERT_TO_CNF_NODES == false')
   }
   #
   $test->nextCase();
   #
   $test->case("Test CNFSQL script to data synch and map.");
   $cnf = CNFParser->new(undef,{DO_ENABLED=>1,DEBUG=>1,'%LOG'=>{console=>1}});
   $cnf->parse(undef,q(
   <<TBL_A<TABLE>
        "name"  varchar(28) NOT NULL,
        "ID" INTEGER NOT NULL,
        PRIMARY KEY ("ID" AUTOINCREMENT)
   >>
   <<TBL_A_DATA<DATA>
   ID`NAME`Gender~
   #`Mickey Mouse`rat~
   5`Donald Duck`food~
   #`Captain Cook`crook~
   >>
   ));
   my $central = $cnf->property('DB_CENTRAL');
   my $db = CNFSQL::_connectDB('test','test',$central->{DBI_SQL_SOURCE},$central->{DB}.'.db');
   $sql = $cnf->SQL();
   $sql -> {data } = $sql2->{parser}->data();
   $sql -> initiDatabase($db,0,{'TBL_A' => ['TBL_A_DATA','name','ID']});
    #
    #
    $test->done();
    #
}
catch{
   $test -> dumpTermination($@);
   $test -> doneFailed();
}
