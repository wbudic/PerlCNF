#!/usr/bin/perl -w
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
use strict;
use warnings;
use Try::Tiny;

#DEFAULT SETTINGS HERE!
use lib "system/modules";
use lib $ENV{'PWD'}.'/htdocs/cgi-bin/system/modules';
require CNFParser;

my $cnf = new CNFParser();

$cnf->parse(undef,q|<<<CONST
    $APP_NAME       = "Test Application"
    $APP_VERSION    = v.1.0
>>>|);



$cnf->parse(undef, q|<<@<@LIST_OF_COUNTRIES>
Australia, USA, "Great Britain", 'Ireland', "Germany", Austria
Spain,      Serbia
Russia
Thailand, Greece
>>>
|);
my @LIST_OF_COUNTRIES = @{$cnf -> collection('@LIST_OF_COUNTRIES')};
print "[".join(',', sort @LIST_OF_COUNTRIES )."]\n";

$cnf->parse(undef, q|<<tag_Some_html<
<p>HTML is Cool!</p> 
>>>|);
print "[tag_Some_html:".$cnf->anon('tag_Some_html')."]\n";
print '[$APP_NAME:'.$cnf->constant('$APP_NAME')."]\n";


1;
