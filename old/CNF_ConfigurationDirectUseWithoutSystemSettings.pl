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

my @content = <DATA>;#<- Magic statment way in perl to slurp whole of the data buffer.
$cnf->parse(undef, \@content);@<- End we pass reference to it otherwise is gets a copy of the buffer.

print "\nArray \@AU_STATES:\n";
my $states = $cnf->collection('@AU_STATES');
foreach(sort @$states){printf "\rState: $_\n"}
print 'A='.$cnf->constant('$A')."\n";
foreach my $prp (sort keys %{$cnf->constants()}){
    print "$prp=", $cnf->constant($prp),"\n";
}

print "\nHash %settings:\n";
my %hsh = %{$cnf->collection('%settings')};
foreach my $key (keys %hsh){
    print "$key=", $hsh{$key},"\n";
}

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

<<<CONST>
  $A='1'
  $B=2
  $C=3
>>>

 <<@<%settings<
     AppName       = "UDP Server"
     port          = 3820
     buffer_size   = 1024
     pool_capacity = 1000    
 >>