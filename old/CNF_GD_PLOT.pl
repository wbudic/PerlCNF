#!/usr/bin/perl


use warnings; 
use Try::Tiny;
use Exception::Class ('CNFParserException');
use DBI;  use GD::Graph::lines;

#DEFAULT SETTINGS HERE!
#LanguageServer doesn't like -> $ENV{'PWD'} settings.json should not be set for it withn an pwd.
#use lib "/home/will/dev/PerlCNF/system/modules/";
use lib "./system/modules/";
require CNFParser;

my $cnf = CNFParser->new('/home/will/dev/PerlCNF/databaseBitcoinPlot.cnf', {DO_enabled=>1});
my $DSN = CNFParser::anon('DBI_SOURCE');
my $alin= $cnf->anon('AUTO_LOGIN');
my ($u,$p) = split '/', $alin;
my $db  =  DBI->connect($DSN, $u, $p, {AutoCommit => 1, RaiseError => 1, PrintError => 0, show_trace=>1});

#my $sql = $cnf->anons('SEL_BITCOIN_30_DAY_RANGE');
my $sql = $cnf->anon('SEL_BITCOIN_3_MONTH_RANGE');
print "$0 SQL -> $sql\n";
my $stm = $cnf-> selectRecords($db, $sql);

my @DAT=();my @MAX=();my @MIN=();my @AVG=();
my $c=0;
while( my @a = $stm->fetchrow_array() ){
  push @DAT, $a[$c++]; push @MAX, $a[$c++]; push @MIN, $a[$c++]; push @AVG, $a[$c++];
   $c=0;
}

my @data = ([@DAT], [@MAX], [@AVG], [@MIN]);

my @dim = @{$cnf->collection('@DIM_SET_BITCOIN')};
my $graph = GD::Graph::lines->new(@dim);
my %hsh = %{$cnf->collection('%HSH_SET_BITCOIN_LINE_PLOT_RANGE')};
$graph->set(%hsh);
$graph->set_legend_font(GD::gdFontTiny);
$graph->set_legend('Max','Avg', 'Min');
my $gd = $graph->plot( \@data ) or die "Error encountered ploting graph: $!";

my $OUT;
open $OUT, ">","./BitcoinCurrentLast30Days.png" or die "Couldn't open for output: $!";
binmode($OUT);
print $OUT $gd->png();
close $OUT;



