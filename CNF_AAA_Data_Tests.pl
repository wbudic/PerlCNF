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

#Test plain anon
my $test = q|<<data$$<a=1>_some_value_>>|;
$cnf->parse(undef,$test);
my @arr = $cnf->list('data');
my %item = %{@arr[0]};
#eval('nona' eq $test) or die "Test on ->$test, failed!";
print q!Test 1:: cnf -> list('data')->id:!.$item{'aid'}.'<'.$item{'ins'}.'><'.$item{'val'}.'>', "\n";
evalTest($test,'0', $item{'aid'});
evalTest($test,'a=1', $item{'ins'});
evalTest($test,'_some_value_', $item{'val'});

my $test = q|<<data$$<a=2`text='we like this?'>
_some_value_2
>>|;
$cnf->parse(undef,$test);
$cnf->{'DO_enabled'}=1;
my @arr = $cnf->list('data');
my %item = %{pop @arr};
#eval('nona' eq $test) or die "Test on ->$test, failed!";
print q!Test 2:: cnf -> list('data')->id:!.$item{'aid'}.'<'.$item{'ins'}.'><'.$item{'val'}.'>', "\n";
evalTest($test,'1', $item{'aid'});
evalTest($test,"a=2`text='we like this?'", $item{'ins'});
evalTest($test,"\n".'_some_value_2'."\n", $item{'val'});

my $test = q|<<data$$<a=3
b=4
c=5>
_some_value_3
>>|;
$cnf->parse(undef,$test);
my @arr = $cnf->list('data');
my %item = %{pop @arr};
print q!Test 3:: cnf -> list('data')->id:!.$item{'aid'}.'<'.$item{'ins'}.'><'.$item{'val'}.'>', "\n";
evalTest("CNF{DO_enabled}",1, $cnf->{'DO_enabled'});
evalTest($test,q|a=3
b=4
c=5|,$item{'ins'});
evalTest($test,"\n".'_some_value_3'."\n", $item{'val'});



sub evalTest{
    my ($test,$a,$b)=@_;
    eval($a eq $b) or die "$0 Test on ->$test, failed!\n\neval(\n\$a->$a\n\$b->$b\n)\n";
}
print "\n\nALL $0 TESTS HAVE PASSED! You did it again, ".ucfirst $ENV{'USER'}."!\n";
1;
