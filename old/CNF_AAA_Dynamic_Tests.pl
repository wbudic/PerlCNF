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
$cnf->parse(undef,q|<<anon<nona>>>|);
my $test = $cnf->anon('anon');
eval('nona' eq $test) or die "Test on ->$test, failed!";
print q!cnf -> anon('anon')->!.$test, "\n";

$cnf->parse(undef,q|<<anon2<nona2> >>|);
my $test = $cnf->anon('anon2');
eval('nona2' eq $test) or die "Test on ->$test, failed!";
print q!cnf -> anon('anon2')->!.$test, "\n";

$cnf->parse(undef,qq|<<anon3>\na1\nb2\nc3\n>>>|);
my $test = $cnf->anon('anon3');
eval(q|a1
b2
c3
| eq $test) or die "Test on ->$test, failed!";
print q!cnf -> anon('anon3')->!.$test, "\n";


# Test constants
$cnf->parse(undef,q|<<<CONST
    $APP_NAME       = "Test Application"
    $APP_VERSION    = v.1.0
>>>|);

$cnf->parse(undef,q|<<$SINGLE<CONST><just like that>>>|);
$test = $cnf->constant('$SINGLE');
eval(q!just like that! eq $test) or die "Test on ->$test, failed!";
print q!cnf -> constant('$SINGLE')->!.$test, "\n";

$cnf->parse(undef,q|<<name<CONST>value>>>|);
$test = $cnf->constant('name');
eval('value' eq $test) or die "Test on ->$test, failed!";
print q!cnf -> constant('name')->!.$test, "\n";

$cnf->parse(undef,q|<<<CONST $TEST= "is best">>>|);
$test = $cnf->constant('$TEST');
eval(q!is best! eq $test) or die "Test on ->$test, failed!";
print q!cnf -> constant('$SINGLE')->!.$test, "\n";

# Test old format single constance.
$cnf->parse(undef,q|<<$TEST2<CONST here we go again>>>|);
$test = $cnf->constant('$TEST2');
eval(q!here we go again! eq $test) or die "Test on ->$test, failed!";
print q!cnf -> constant('$TEST2')->!.$test, "\n";

# Test instruction containing constance links.
$cnf->parse(undef,q|<<<CONST $REPO_PATH=/home/repo>>>
<<FULL_PATH<$$$$REPO_PATH$$$/my_app>>>
|);
$test = $cnf->anon('FULL_PATH');
eval(q!/home/repo/my_app! eq $test) or die "Test on ->$test, failed!";
print q!$cnf->anon('FULL_PATH')->!.$test, "\n";


# Test MACRO containing.
$cnf->parse(undef,q|<<<CONST M1=replaced_m1>>><<<CONST M2=replaced_m2>>>
<<Test<MACRO>
1. $$$M1$$$ line1.
2. $$$M2$$$ line2 m2 here.
3. $$$M1$$$ line1. m1 here too.>>
|);
$test = $cnf->anon('Test');
print q!$cnf->anon('Test')->!.$test, "\n";
eval(q!1. replaced_m1 line1.
2. replaced_m2 line2 m2 here.
3. replaced_m1 line1. m1 here too.! eq $test) or die "Test on ->$test, failed!";




# Test Arrays
$cnf->parse(undef, q|<<@<@LIST_OF_COUNTRIES>
Australia, USA, "Great Britain", 'Ireland', "Germany", Austria
Spain,      Serbia
Russia
Thailand, Greece
>>>
|);
my @LIST_OF_COUNTRIES = @{$cnf -> collection('@LIST_OF_COUNTRIES')};
$test = "[".join(',', sort @LIST_OF_COUNTRIES )."]";
eval(
q![Australia,Austria,Germany,Great Britain,Greece,Ireland,Russia,Serbia,Spain,Thailand,USA]!
    eq $test) or die "Test on ->$test, failed!";
print q!cnf -> collection('@LIST_OF_COUNTRIES')->!.$test, "\n";

$cnf->parse(undef, q|<<tag_Some_html<
<p>HTML is Cool!</p> 
>>>|);
$test = "[tag_Some_html:".$cnf->anon('tag_Some_html')."]";
eval(    
qq([tag_Some_html:\n<p>HTML is Cool!</p> 
]) eq $test 
) or die "Test on ->$test, failed!";
print "$test\n";

$test='[$APP_NAME:'.$cnf->constant('$APP_NAME')."]";
eval(q![$APP_NAME:Test Application]! eq $test) or die "Test on ->$test, failed!";
print "$test\n";





print "\n\nALL TESTS HAVE PASSED! You did it again, ".ucfirst $ENV{'USER'}."!\n";
1;
