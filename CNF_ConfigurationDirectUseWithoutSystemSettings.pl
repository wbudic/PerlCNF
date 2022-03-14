#!/usr/bin/perl -w
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
use strict;
use warnings;
use Exception::Class ('CNFParserException');
use Try::Tiny;

use lib "system/modules/";
require system::modules::CNFParser;
my $cnf = CNFParser->new(undef, {DO_enabled=>1,CONSTANT_REQUIRED=>1});
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
try {
  print "\$none=".$cnf->constant('$none')."\n";
}
catch  {
  print "call on \$none cause exception -> $_";
  if ( $_->isa('CNFParserException') ) {
        warn $_->trace->as_string, "\n";
  }
  
};

 my @content = <DATA>;
$cnf->parse(undef, \@content);
my $states = $cnf->collection('@AU_STATES');
foreach(sort @$states){printf "\rState: $_\n"}

__DATA__
!CNF2.4
This is the power of Perl, the perls source file can contain the config file itself!
What you are now reading is the config __DATA__ section tha can be passed to the PerlCNF parser.
Check it out it is better than JSON:
<<@<@AU_STATES<
NSW
TAS,'WA'
'SA'
QLD, VIC
>>