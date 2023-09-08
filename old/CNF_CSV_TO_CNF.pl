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
use open qw( :std :encoding(UTF-8) );

#DEFAULT SETTINGS HERE!
use lib "system/modules";
use lib $ENV{'PWD'}.'/htdocs/cgi-bin/system/modules';
require CNFParser;


my $cnf = new CNFParser();
$cnf->parse(undef,q!<<@<%DATA_MAP_TO_CSV<
updated         = 'last updated'
suburb          = suburb
exposure_dt     = 'date and time of exposure'
venue           = venue
>>>
!);
my %map = %{$cnf->property('%DATA_MAP_TO_CSV')};
my @mkeys = sort keys %map;# we have to sort as keys are returned inconviently unorderly, each time fetched.
my $csv = Text::CSV->new({  binary => 1, auto_diag => 1, sep_char => ',' });
my @header = 0;

my $file ='20210720- COVID-19 case locations and alerts in NSW - COVID-19 (Coronavirus) .csv';
open(my $fh, '<', $file) or die "Could not open $file $!\n";
open(my $fhOut, '>', '20210720-cv19-cases-data.cnf') or die "Could not open $file $!\n";

print $cnf -> writeOut($fhOut,'%DATA_MAP_TO_CSV');
print $fhOut "<<DATA<DATA\n";
$csv->header ($fh);
while (my $r=$csv->getline_hr ($fh)) {
       my %row = %{$r};
       my $line = "";
       foreach my $k(@mkeys){
            my $n = $map{$k};
            my $v = $row{$n};
            $line .= $v.'`';
       }
       $line =~ s/`$/~\n/;
       print $fhOut $line;

      #print Dumper($r), "\n";      last;
}
print $fhOut ">>>\n";
close $fhOut;
close $fh;
1;

