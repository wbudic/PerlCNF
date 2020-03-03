#!/usr/bin/perl -w
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
use strict;
use warnings;
use DBI;
use Exception::Class;


use lib "system/modules";
use lib $ENV{'PWD'}.'/htdocs/cgi-bin/system/modules';

require Settings;


my $dsn      = "DBI:SQLite:dbname=/home/will/dev/LifeLog/dbLifeLog/data_admin_log.db";
my $db       = DBI->connect( $dsn, "admin", "admin", { PrintError => 0, RaiseError => 1 } )
                      or Exception->throw("Connect failed [$_]");

Settings::getConfiguration($db,{backup_enabled=>1});
print "backup_enabled1:[".Settings::anon('backup_enabled')."]\n";
my @r = Settings::anons();
print "anon_size:[".@r."]@r\n";


Settings::getConfiguration($db);#in file set to 0
print "backup_enabled2:[".Settings::anon('backup_enabled')."]\n";
Settings::getConfiguration($db,{backup_enabled=>1});#this is later, code set.
print "backup_enabled3:[".Settings::anon('backup_enabled')."]\n";
Settings::getConfiguration($db);#Murky waters, can't update an anon later through code. Config initially set.
print "backup_enabled4:[".Settings::anon('backup_enabled')."]\n";

# my $s1 ="`1`2`3`te\\`s\\`t`the best`";

#  $s1 =~ s/\\`/\\f/g;
#  #print $s1,"\n";
# foreach (  split ( /`/, $s1)  ){
#     $_ =~ s/\\f/`/g;
#     print $_,"\n";
# }
# print "Home:".$ENV{'PWD'}.$ENV{'NL'};



1;
