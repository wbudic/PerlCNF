#!/usr/bin/perl -w
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
use strict;
use warnings;
use Try::Tiny;
use Exception::Class ('CNFParserException');

#DEFAULT SETTINGS HERE!
use lib "system/modules";
use lib $ENV{'PWD'}.'/htdocs/cgi-bin/system/modules';
require CNFParser;

sub cnfCalled{
    my %passed= %{$_[0]};
    print "cnfCalled [".%passed."]\n";
    print "cnfCalled %[pool_capacity]=".$passed{'pool_capacity'}."\n";
}

my $cnf = new CNFParser($ENV{'PWD'}.'/test_properties.cnf');
my @animals = @{$cnf->property('@animals')};
my %colls = $cnf->propertys();
my %settings = %{$cnf->property('%settings')};
print "AppName = ".$settings{'AppName'}, "\n";
print "Pop music is a ", pop @animals, "!\n";
print "CNF_PROCESSING_DATE -> ", $cnf -> anons('CNF_PROCESSING_DATE'), "\n";

1;
