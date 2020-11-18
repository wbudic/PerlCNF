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


#DEFAULT SETTINGS HERE!
use lib "system/modules";

use lib $ENV{'PWD'}.'/htdocs/cgi-bin/system/modules';
require CNFParser;

testAnons();



sub testAnons {

my $cnf = CNFParser->new($ENV{'PWD'}."/databaseAnonsTest.cnf");

my $exe = $cnf->anons('list_cmd', $ENV{'PWD'});
print "Exe is:$exe\n";
$exe = `$exe`;
print "Error failed system command!" if !$exe;
#print "Listing:\n$exe\n";

print "\n--LIST OF ALL ANONS ENCOUNTERED---\n";
my %anons = $cnf->anons();
foreach my $k (keys %anons){
    print "Key->$k=", $anons{$k},"]\n";
}
eval((keys %anons) == 7) or die "Error annons count mismatch!";

eval(length($cnf->constant('$HELP'))>0) or die 'Error missing multi-line valued constant property $HELP';

my $template = $cnf ->  template( 'MyTemplate', (
                                                'SALUTATION'=>'Mr',
                                                'NAME'=>'Prince Clington',
                                                'AMOUNT'=>"1,000,000\$",
                                                'CRITERIA'=>"Section 2.2 (Eligibility Chapter)"
                                )
                        );

print "\n--- TEMPLATE ---\n".$template;

### From the specs.
my $url = $cnf->anons('GET_SUB_URL',('tech','main.cgi'));
# $url now should be: https://www.tech.acme.com/main.cgi
eval ($url =~ m/https:\.*/)
or warn "Failed to obtain expected URL when querying anon -> GET_SUB_URL";
eval ($url eq 'https://www.tech.acme.com/main.cgi') or die "Error with: $url";
}


1;
