#!/usr/bin/perl -w
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
use strict;
use warnings;
use Try::Tiny;
use Test::More;
use Test::Vars;

use DateTime;
use DateTime::Format::SQLite;
use DateTime::Duration;
use DBI;
use Exception::Class ('CNFParserException');


#DEFAULT SETTINGS HERE!
use lib "system/modules";
require CNFParser;

our $pwd;
sub BEGIN {
$pwd = `pwd`; $pwd =~ s/\/*\n*$//;
}

my $cnf = new CNFParser('databaseProgresSQL.cnf');

print "resw".$cnf->isReservedWord('TABLE');
print "resw:".$cnf->isReservedWord();
my $DSN = $cnf->anon('DBI_SOURCE');
my $alin= $cnf->anon('AUTO_LOGIN');
#my $sql = $cnf->tableSQL('BITCOIN');
my ($u,$p) = split '/', $alin;
my $db  =  DBI->connect($DSN, $u, $p, {AutoCommit => 1, RaiseError => 1, PrintError => 0, show_trace=>1});

$cnf->initiDatabase(\$db);
foreach my $const(keys %{$cnf->constants()}){
    print $const, "\n";

}


our $APP_VER = $cnf->constant('$APP_VER'); $APP_VER++;
print $APP_VER, "\n";
our $APP_VER1 = $cnf->constant('$APP_VER');
print $APP_VER1, "\n";

1;
