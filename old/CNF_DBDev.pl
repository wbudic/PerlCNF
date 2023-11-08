#!/usr/bin/perl -w
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
use strict;
use warnings;
use Try::Tiny;

use DateTime;
use DateTime::Format::SQLite;
use DateTime::Duration;
use DBI;

#DEFAULT SETTINGS HERE!
use lib "system/modules";
use lib $ENV{'PWD'}.'/htdocs/cgi-bin/system/modules';
require CNFParser;
require Settings;


my ($dsn, $db,$res,$stm,$dbver,$st,$cnf);
my $today = DateTime->now;
   $today->set_time_zone( &Settings::timezone );


&testSettingsForStatementsInLifeLogDB;


sub testSettingsForStatementsInLifeLogDB {

   $cnf = CNFParser->new();
   $dsn= "DBI:SQLite:dbname=".$ENV{'PWD'}.'/dbLifeLog/data_admin_log.db';
   $db = DBI->connect($dsn, 'admin', 'admin', { RaiseError => 1 }) or die "Error->". &DBI::errstri;


   print "Log records count:",Settings::selectRecords($db, 'select count(*)from LOG;')->fetchrow_array(),"\n";
   print "--Sample--\n",

    my $pst1 =  Settings::selectRecords($db, 'select rowid, date, log from LOG order by date desc limit 10;');
    my $st	= $db->prepare('select rowid, date, log from LOG order by date desc;');
    $st->execute() or die "<p>ERROR with->$_</p>";


   foreach (my @r = $pst1->fetchrow_array()) {
        my $lid =  $r[0];
        my $dat =  $r[1];
        my $log =  $r[2];
        if(length($log)>60){
            print sprintf("%4d %s %.60s...\n", $lid, $dat, $log);
        }else{
            print sprintf("%4d %s %0s\n", $lid, $dat, $log);
        }

   }

   my $pst = Settings::selectRecords($db,"SELECT name FROM sqlite_master WHERE type='table';");
   my %curr_tables = ();
   while(my @r = $pst->fetchrow_array()){
        $curr_tables{$r[0]} = 1;
   }
   my $check; if ($curr_tables{"LOG"}){$check = 'yes'} else{ $check = 'no'};
   print "Has Log table? ->", $check, "\n";
   if ($curr_tables{"DOODLE"}){$check = 'yes'} else{ $check = 'no'};
   print "DOODLE table? ->", $check, "\n";

   $check = Settings::selectRecords($db,"SELECT ID FROM CAT WHERE name ==  'System Log';")->fetchrow_array();
   $check = 0 if not $check;
   print "0==$check\n";
   $db->disconnect();

exit;
}

$cnf = CNFParser->new();

$cnf->parse($ENV{'PWD'}."/dbLifeLog/databaseInventory.cnf");



$dsn = "DBI:SQLite:dbname=".$ENV{'PWD'}.'/dbLifeLog/'.$cnf->constant('$DATABASE');

 $db = DBI->connect($dsn, $cnf->constant('$LOGIN_USER'), $cnf->constant('$LOGIN_PASS'), { RaiseError => 1 })
              or die "Error->". &DBI::errstri ;
$dbver = $cnf->initDatabase($db);


$dsn= "DBI:SQLite:dbname=".$ENV{'PWD'}.'/dbLifeLog/'.$cnf->constant('$DATABASE');

print "Acessing: $dsn\n";

## We have all the table statments, so let's check issue them first.
foreach my $tbl ($cnf->tables()){

    if($cnf->tableExists($db, $tbl)){
        print "Table -> $tbl found existing.\n";
    }
    else{
        $stm = $cnf->tableSQL($tbl);

        if($db->do($stm)){
            print "Created table: $tbl \n";
        }
        else{
            print "Failed -> \n$stm \n";
        }
    }

}



foreach my $tbl ($cnf->dataKeys()){
    my ($sel,$ins, $seu, $upd, @prm, @arr);#locals
    try{
        print "Processing table data for ->", $tbl , "\n";
        $stm = $cnf->tableSQL($tbl);

        if(!$stm){
            print "Failed to obtain table statment for table data -> $tbl\n";
        }else{
            @arr = getStatements($tbl, $stm);
            $sel = $db->prepare($arr[0]);
            $ins = $db->prepare($arr[1]);
            $seu = $db->prepare($arr[2]);
            $upd = $db->prepare($arr[3]);
            foreach my $ln ($cnf->data($tbl)){
                #print "dataln-> $ln\n";
                @prm = ();
                foreach my $p (split(/','/,$ln)){
                    $p =~ s/^'|'$//g;
                    push @prm, $p;
                }
                $sel->execute(@prm);
                my @ret = $sel -> fetchrow_array();
                if(@ret){
                    print "Exists -> ".delim(@prm)," <- UID: $ret[0]", "\n";
                }
                else{
                    my $uid = shift @prm;
                       $seu->execute($uid);
                       @ret = $seu -> fetchrow_array();
                    if(@ret){
                        push @prm, $uid;
                        @ret = $upd->execute(@prm);
                        print "Updated -> ".delim(@prm), "\n";
                    }else{
                        unshift @prm, $uid;
                        $ins->execute(@prm);
                        print "Added -> ".delim(@prm), "\n";
                    }
                }
            }
        }

     }catch{
        print "Error:$_\n";
        print "Error on->$tbl exeprms[",delim(@prm),"]\n";
        foreach my $ln ($cnf->data($tbl)){
                print "dataln-> $ln\n";
        }
    }

}

sub delim {
    my $r;
    foreach(@_){$r.=$_.'`'}
    $r=~s/`$//;
    return $r;
}

sub getStatements {

    my ($tbl, $stm) = @_;
    my @ret = ();
    my ($sel,$ins, $seu, $upd, $upe);

    $sel = "SELECT * FROM $tbl WHERE ";
    $ins = "INSERT INTO $tbl VALUES(";
    $upd = "UPDATE $tbl SET ";

    $stm =~ s/^.*\(\s+//g;
    $stm =~ s/\n\s*|\n\);/\n/g;
    $stm =~ s/\);//g;

   # print "<<$stm>>\n";

    foreach my $n (split(/,\s*/,$stm)){
        $n =~ /(^\w+)/;
        #print $1, "\n";
        $sel .= "$1=? AND ";
        $seu .= "SELECT * FROM $tbl WHERE $1=?;" if !$seu;
        $ins .= "?,";
        if (!$upe){
             $upe = " WHERE $1=?";
        }else{
             $upd .= "$1=?,";
        }
    }
    $sel =~ s/\sAND\s$/;/g;
    $ins =~ s/,$/);/g;
    $upd =~ s/,$/$upe/g;

    push @ret, $sel;
    push @ret, $ins;
    push @ret, $seu;
    push @ret, $upd;

  #  print delim(@ret)."\n";

    return @ret;
}


1;
