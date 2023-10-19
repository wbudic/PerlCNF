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


   $test->case("Test local SQL Database Setup.");
    my $content = do {local $/;<DATA>};
   $cnf = CNFParser->new(undef,{DO_ENABLED=>1,DEBUG=>1,'%LOG'=>{console=>1}});
   $cnf->parse(undef,$content);
   my $sql = $cnf->SQL();
   $test->subcase("Test CNFSQL obtained.");
   $test->evaluate("Is CNFSQl ref?","CNFSQL", ref($sql));
   my $db = CNFSQL::_connectDB('test','test','DBI:SQLite:','test_tasks.db');
   $sql->initiDatabase($db,0);
   #
   $test->nextCase();
   #
   #
      $test->done();
   #
}
catch{
   $test -> dumpTermination($@);
   $test -> doneFailed();
}

__DATA__
!CNF3.0
<< TASKS <DATA> __SQL_TABLE__
ID`Date _DATE_ `Due _DATE_ `Task __TEXT__`Completed _BOOL_`Priority __INT_~
#`2023-10-18`2023-11-22`Write test.`0`1~
#`2023-10-18`2023-12-01`Implement HSHContact.`0`1~
>><<PRIORITIES <DATA>
ID`Name`
1`High`~
2`Medium`~
3`Low`~
>>