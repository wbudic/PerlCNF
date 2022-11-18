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
    my %lists = %{$cnf->lists()};
    foreach my $l (keys %lists){
        print "List->$l\n";
    }
    my @c = $cnf->list('CAT');
    foreach (@c){ next if not $_;
    print "Ele in CAT->$_\n"
    }
    my @a = $cnf->listDelimit('\n', 'COUNTRIES');
    @c = $cnf->list('COUNTRIES');
    foreach (@c){ next if not $_;
    print "Ele.delimited in COUNTRIES->$_\n"
    } 
    @c = $cnf->list('PATHS');
    my @paths =  $cnf->listDelimit(':', 'PATHS');
    foreach (@paths){ 
    print "Ele.delimited in PATHS->$_\n"
    } 

    foreach (@c){ 
    print "Ele PATHS->$_\n"
    } 
     @c = $cnf->list('PATHS');
    foreach (@c){ 
    print "Ele2 PATHS->$_\n"
    } 
}

sub listDelimit {                 
                 my ($d,$t, $cnf)=@_;
                 my %h = $cnf->lists();
                 my $p = $h{$t};
                 if($p&&$d){
                    #my @find = @{$p};
                    my @ret = ();
                    foreach (@$p){
                        my @s = split $d, $_;
                        push @ret, @s;

                    }
                    $h{$t}=\@ret;
                    return @ret;
                 }
                 return;
            
    }

1;
