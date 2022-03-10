#!/usr/bin/perl -w
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
use strict;
use warnings;
use Exception::Class ('CNFParserException');

use lib "system/modules/";
require CNFParser;
my $cnf = new CNFParser(undef, {DO_enabled=>1,CONSTANT_REQUIRED=>1});
$cnf->parse(undef,
q{
/*
  Instead setting constant variables in perl that are used only once in the code.
  The config can hold them only, so only there it changes, and also holds the default values.
  If the value changes is not constant, Setting module needs to be used instead.
*/
<<<CONST
            $APP_VER = 1.0
            $DEBUG   = 0
>>
}
);

my $APP_VER = $cnf->constant('$APP_VER');
print "\$APP_VER=$APP_VER\n";
#Better use:
print "\$DEBUG=".$cnf->constant('$DEBUG')."\n";
print "\$none=".$cnf->constant('$none')."\n";
1;
