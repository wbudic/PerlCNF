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
use Exception::Class ('CNFParserException');

#DEFAULT SETTINGS HERE!
use lib "system/modules";
use lib $ENV{'PWD'}.'/htdocs/cgi-bin/system/modules';
require CNFParser;

my $cnf = new CNFParser($ENV{'PWD'}.'/databaseProgresSQL.cnf');
print "resw".$cnf->isReservedWord('TABLE');
print "resw:".$cnf->isReservedWord();
my $DSN = $cnf->anons('DBI_SOURCE');
my $alin= $cnf->anons('AUTO_LOGIN');
my $sql = $cnf->tableSQL('BITCOIN');
my ($u,$p) = split '/', $alin;
my $db  =  DBI->connect($DSN, $u, $p, {AutoCommit => 1, RaiseError => 1, PrintError => 0, show_trace=>1});

$cnf->initiDatabase($db);
foreach my $const(keys %{$cnf->constants()}){
    print $const, "\n";

}


our $APP_VER = $cnf->constant('$APP_VER'); $APP_VER++;
print $APP_VER, "\n";
our $APP_VER1 = $cnf->constant('$APP_VER');
print $APP_VER1, "\n";

1;
