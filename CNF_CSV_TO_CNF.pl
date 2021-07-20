#!/usr/bin/perl -w
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
use strict;
use warnings;
use Try::Tiny;

use Text::CSV;
use Data::Dumper;
local $Data::Dumper::Terse = 1;

#DEFAULT SETTINGS HERE!
use lib "system/modules";
use lib $ENV{'PWD'}.'/htdocs/cgi-bin/system/modules';
require CNFParser;


#my $cnf = new CNFParser();

my $csv = Text::CSV->new({  binary => 1, auto_diag => 1, sep_char => ',' });
my @header = 0;

my $file ='20210720- COVID-19 case locations and alerts in NSW - COVID-19 (Coronavirus) .csv';
open(my $fh, '<', $file) or die "Could not open $file $!\n";
$csv->header ($fh);
while (my $row = $csv->getline_hr ($fh)) {  
      print Dumper($row), "\n";      
}
close $fh;
__DATA__
<<DATA_MAP_TO_CSV<
updated         = 'last updated'
exposure_dt     = 'date and time of exposure'
suburb          = suburb
venue           = venue
>>>
