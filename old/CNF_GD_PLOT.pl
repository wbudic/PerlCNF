#!/usr/bin/perl

#use strict;
use warnings;
use Try::Tiny;
use Exception::Class ('CNFParserException');
use DBI;
use GD::Graph::lines;

#DEFAULT SETTINGS HERE!
#LanguageServer doesn't like -> $ENV{'PWD'} settings.json should not be set for it withn an pwd.
#use lib "system/modules/";
use lib "system/modules";
require CNFParser;

my $cnf = CNFParser->new('old/databaseBitcoinPlot.cnf', {DO_ENABLED=>1,ANONS_ARE_PUBLIC=>1}); #Since v.2.6 ANONS_ARE_PUBLIC=>0 is assumed if not specified.
my $DSN = CNFParser::anon('DBI_SOURCE'); #<- Global static access we use, as it is available, it is same as: $cnf->anon('DBI_SOURCE');
my $alin= $cnf->anon('AUTO_LOGIN');
my ($u,$p) = split '/', $alin;
my $db  =  DBI->connect($DSN, $u, $p, {AutoCommit => 1, RaiseError => 1, PrintError => 0, show_trace=>1});

#my $sql = $cnf->anons('SEL_BITCOIN_30_DAY_RANGE');
my $sql = $cnf->SQL()->{'SEL_BITCOIN_3_MONTH_RANGE'};
print "$0 SQL -> $sql\n";
my $stm = CNFParser::SQL() -> selectRecords($db, $sql);

my @DAT=();my @MAX=();my @MIN=();my @AVG=();
my $c=0;
while( my @a = $stm->fetchrow_array() ){
  push @DAT, $a[$c++]; push @MAX, $a[$c++]; push @MIN, $a[$c++]; push @AVG, $a[$c++];
   $c=0;
}

my @data = ([@DAT], [@MAX], [@AVG], [@MIN]);

my @dim = $cnf->property('@DIM_SET_BITCOIN');
my $graph = GD::Graph::lines->new(@dim);
my %hsh = $cnf->property('%HSH_SET_BITCOIN_LINE_PLOT_RANGE');
$graph->set(%hsh);
$graph->set_legend_font(GD::Graph::gdFontTiny);
$graph->set_legend('Max','Avg', 'Min');
my $gd = $graph->plot( \@data ) or die "Error encountered ploting graph: $!";

my $OUT;
open $OUT, ">","./BitcoinCurrentLast30Days.png" or die "Couldn't open for output: $!";
binmode($OUT);
print $OUT $gd->png();
close $OUT;




