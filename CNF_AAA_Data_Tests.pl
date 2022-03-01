#!/usr/bin/perl -w
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
use strict;
use warnings; #use warnings::unused;

#DEFAULT SETTINGS HERE!
our $pwd; 
sub BEGIN {# Solution for vcode not being perl environment friendly. :(
    $pwd = `pwd`; $pwd =~ s/\/*\n*$//;    
}
#use lib $ENV{'PWD'}.'/htdocs/cgi-bin/system/modules';

use lib "system/modules";
use lib "$pwd/system/modules";
require TestManager;


our $test = TestManager->create({name=>$0,count=>0});

$test->checkPackage('CNFParser');
$test->startCase('Test list item named "data"');
require CNFParser;
my $cnf = new CNFParser();
my $exp = q|<<data$$<a=1>_some_value_>>|;
$cnf->parse(undef,$exp);
    my @arr = $cnf->list('data');
    my %item = %{$arr[0]};    
    $test->info(q!cnf -> list('data')->id:!.$item{'aid'}.'<'.$item{'ins'}.'><'.$item{'val'}.'>', "\n");
    $test->eval('0', $item{'aid'});
    $test->eval('a=1', $item{'ins'});
    $test->eval('_some_value_', $item{'val'});
$test->endCase();

$test->startCase('Test list item named "data" with delimited instruction.');
$exp = q|<<data$$<a=2`text='we like this?'>
_some_value_2
>>|;
    $cnf->parse(undef,$exp);
    $cnf->{'DO_enabled'}=1;
    @arr = $cnf->list('data');
    %item = %{pop @arr};

    $test->info(q!cnf -> list('data')->id:!.$item{'aid'}.'<'.$item{'ins'}.'><'.$item{'val'}.'>', "\n");
    $test->eval('1', $item{'aid'});
    $test->eval("a=2`text='we like this?'", $item{'ins'});
    $test->eval("\n".'_some_value_2'."\n", $item{'val'});
$test->endCase();

$test->startCase('Test list item named "data" with nl delimited instruction.');
$exp = q|<<data$$<a=3
b=4
c=5>
_some_value_3
>>|;
    $cnf->parse(undef,$exp);
    @arr = $cnf->list('data');
    %item = %{pop @arr};
    $test->info(q!Test 3:: cnf -> list('data')->id:!.$item{'aid'}.'<'.$item{'ins'}.'><'.$item{'val'}.'>', "\n");
    $test->eval("CNF{DO_enabled}", $cnf->{'DO_enabled'}, 1);
    $test->eval("a=3\nb=4\nc=5",$item{'ins'});
    $test->eval("\n".'_some_value_3'."\n", $item{'val'});
$test->endCase();

$test->finish();
print "\n\nALL $0 TESTS HAVE PASSED! You did it again, ".ucfirst $ENV{'USER'}."!\n";
1;
