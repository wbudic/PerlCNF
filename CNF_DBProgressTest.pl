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

# my $content = q(
# <<<CONST
# $APP_NAME=CNF Configuration Toll Testing
# $APP_VER=1.0
# $RELEASE_VER = 2.2`Current CNF version under test.
# >>
# );

# my $content = q(
# <<BITCOIN<TABLE
# date timestamp without time zone NOT NULL,
# value integer NOT NULL
# >>
# );


#     my @tags =  ($content =~ m/(<<)(\$*<*.*?)(>>+)/gms);
            
#     foreach my $tag (@tags){             
# 	  next if not $tag;
#       next if $tag =~ m/^(>+)|^(<<)/;
#       print $tag."\n";
#     }




my $today = DateTime->now;   
my $cnf = new CNFParser($ENV{'PWD'}.'/databaseProgresSQL.cnf');
my $DSN = $cnf->anons('DBI_SOURCE');
my $alin= $cnf->anons('AUTO_LOGIN');
my $sql = $cnf->tableSQL('BITCOIN');
my ($u,$p) = split '/', $alin;
my $db  =  DBI->connect($DSN, $u, $p, {AutoCommit => 1, RaiseError => 1, PrintError => 0, show_trace=>1});

$cnf->initiDatabase($db);






1;
