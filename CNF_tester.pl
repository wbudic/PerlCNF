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
use Text::CSV;

#DEFAULT SETTINGS HERE!
use lib "system/modules";
use lib $ENV{'PWD'}.'/htdocs/cgi-bin/system/modules';
require Settings;

my $today  = DateTime->now;
$today->set_time_zone( &Settings::timezone );
print $today;

# use lib $ENV{'PWD'}.'/htdocs/cgi-bin/system/modules';
# require CNFParser;

# my $cnf = CNFParser->new();
# $cnf->parse($ENV{'PWD'}."/dbLifeLog/database.cnf");

# foreach ($cnf->SQLStatments()){
#     print "$_\n";
# }
# foreach my $p ($cnf->constants()){

#     print "$p=", $cnf->constant($p),"\n";
# }
# print "\n---ANNONS---\n";
# my %anons = $cnf->anons();
# foreach my $k (%anons){
#     print "$k=", $anons{$k},"\n" if $k;
# }
# foreach (sort keys %ENV) {
#   print "$_= $ENV{$_}\n";
# }

### CGI END
1;
