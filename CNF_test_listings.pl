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

testListings();



sub testListings {

    my $cnf = CNFParser->new($ENV{'PWD'}."/test_listings.cnf");

    print "--LIST OF ALL LIST TAGS ENCOUNTERED---\n";
    my %lists = $cnf->lists();
    foreach my $l (keys %lists){
        print "List->$l\n";
    }
    my @c = $cnf->list('CAT');
    foreach (@c){ next if not $_;
    print "Ele in CAT->$_\n"
    }
    my @c = $cnf->list('COUNTRIES');
    foreach (@c){ next if not $_;
    print "Ele in COUNTRIES->$_\n"
    }
}

1;
