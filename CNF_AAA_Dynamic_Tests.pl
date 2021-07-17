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

# my %p = ('$path$'=>"__PATH__");
# my $t= q($path$/replace
# with $path$
# );
# if(defined $t){ #unknow tagged instructions value we parse for macros.
#     foreach ($t =~ /(\$.*\$)/) {
#         my $r = $p{$_};
#         die "Unable to find property -> $_\n" if !$r;
#         $t =~ s/$_/$r/g;
#     }
# }


# print $t, "\n";


my $cnf = new CNFParser();


# Test constants
$cnf->parse(undef,q|<<<CONST
    $APP_NAME       = "Test Application"
    $APP_VERSION    = v.1.0
>>>|);

$cnf->parse(undef,q|<<$SINGLE<CONST><just like that>>>|);
my $test = $cnf->constant('$SINGLE');
eval(q!just like that! eq $test) or die "Test on ->$test, failed!";
print q!cnf -> constant('$SINGLE')->!.$test, "\n";

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
# my $s1='$$$$REPO_PATH$$$';
# my $r ='/home/repo';
# my $s2='$$$$REPO_PATH$$$/my_app';
# $s2 =~ s/\Q$s1\E/$r/g;
$cnf->parse(undef,q|<<<CONST $REPO_PATH=/home/repo>>>
<<FULL_PATH<$$$$REPO_PATH$$$/my_app>>>
|);
$test = $cnf->anon('FULL_PATH');
eval(q!/home/repo/my_app! eq $test) or die "Test on ->$test, failed!";
print q!$cnf->anon('FULL_PATH')->!.$test, "\n";

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
\<p>HTML is Cool!</p> 
>>>|);
$test = "[tag_Some_html:".$cnf->anon('tag_Some_html')."]";
eval(    
q([tag_Some_html:\<p>HTML is Cool!</p> 
]) eq $test 
) or die "Test on ->$test, failed!";
print "$test\n";

$test='[$APP_NAME:'.$cnf->constant('$APP_NAME')."]";
eval(q![$APP_NAME:Test Application]! eq $test) or die "Test on ->$test, failed!";
print "$test\n";





print "\n\nALL TESTS HAVE PASSED! You did it again, ".ucfirst $ENV{'USER'}."!\n";
1;
