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
my $DB_SETTINGS = qq(
<<<CONST
   DB              = test_db_central
   DB_CREDENTIALS  = admin/admin
   DB_SQL_SOURCE   = DBI:Pg:host=localhost;port=5433;
>>>
);
try{

   die $test->failed() if not $cnf = CNFParser->new(undef,{'%LOG'=>{console=>1}});
       $test->case("Passed new instance CNFParser.");
           #

   $cnf->parse(undef,$DB_SETTINGS);
   my($user,$pass,$source,$store)=(CNFSQL::_credentialsToArray($cnf->{DB_CREDENTIALS}),$cnf->{DB_SQL_SOURCE},$cnf->{DB});
   our ($db,$test_further) = (undef,1);
   try{
       $db = CNFSQL::_connectDB($user,$pass,$source,$store);
   }catch($e){
      $test_further = 0;
      $test->passed("Skipping further testing unable to connect to <<<DB_SQL_SOURCE $cnf->{DB_SQL_SOURCE} >>> \n$e")
   }
   if($test_further){
      $test->case("initDatabase");
      my $content = do {local $/;<DATA>};
      $cnf->parse(undef, $content);
      $cnf->SQL()->initDatabase($db);
   }

    #
    $test->done();
    #
}
catch{
   $test -> dumpTermination($@);
   $test -> doneFailed();
}


=begin postgreSQL setup
$> psql -U postgres -p 5433 -h localhost

CREATE USER admin SUPERUSER LOGIN PASSWORD 'admin';
CREATE DATABASE test_db_central;
grant all privileges on database test_db_central to admin;
=cut

__DATA__
!CNF3.0
// The spaced out data column header and its meta type settings are spaced out,
// bellow for your readabilty, this is  allowed in CNF. not in any other scripted data format.
<< TASKS <DATA> __SQL_TABLE__   __SQL_PostgreSQL__
ID  _CNF_ID_
 `Date                                         _DATE_
            `Due                               _DATE_
                       `Task                   _TEXT_
                                  `Completed   _BOOL_
                                     `Priority _ID__~
#`2023-10-18`2023-11-22`Write test.`0`1~
#`2023-10-18`2023-12-01`Implement HSHContact.`0`5~
#`2023-12-1`2023-12-21`Deploy HSHContact.`0`5~
>>

<< TASKS_AUTO_VARIANT <DATA> __SQL_TABLE__   __SQL_PostgreSQL__
ID`Date  _DATE_`Due                            _DATE_
                       `Task                   _TEXT_
                                  `Completed   _BOOL_
                                     `Priority _ID__~
#`2023-10-18`2023-11-22`Write test.`0`1~
#`2023-10-18`2023-12-01`Implement HSHContact.`0`5~
#`2023-12-1`2023-12-21`Deploy HSHContact.`0`5~
>>