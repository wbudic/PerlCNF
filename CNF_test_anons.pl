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

# my $random_iter1 = my_srand (100);
# my $random_iter2 = my_srand (1099);
# for (0..100) {
#     print &$random_iter1(), " ", &$random_iter2, "\n";
# }


#testRef();
#testAnonsParser();
testAnons();


sub my_srand {my ($rand) = @_; return sub {$rand = ($rand*21+1)%1000}}

sub testAnonsParser {
my $cnf = CNFParser->new($ENV{'PWD'}."/anonsTest.cnf");

my %anons = sort $cnf->anons();
print "Find key 1 -> value=", $cnf->anons("1",undef), "\n";
print "Find key 2 -> value=", $cnf->anons("2",undef), "\n";
print "Find key 3 -> value=", $cnf->anons("3",undef), "\n";
print "Find key 4 -> value=", $cnf->anons("4",undef), "\n";
print "Find key 5 -> value=", $cnf->anons("5",undef), "\n";
foreach my $k (keys %anons){
    print "Key->[$k=", $anons{$k},"]\n";
}
eval{ scalar keys %anons == 5 } or die "Error annons count mismatch!";

exit;


my $hshs  = $cnf->collections();

my $arr1 = $cnf->collection('@arr1');
my $arr2 = $cnf->collection('@arr2');
my $arr3 = $cnf->collection('@arr3');

print 'CNFParser.$VERSION is '.${CNFParser::VERSION}, "\n" . '-' x 80,"\n";

print map {$_?'['.$_.']':"\n"} @{$arr1}, "\n";
print map {'['.$_.']'} @{$arr2}, "\n";
print map {'['.$_.']'} @{$arr3}, "\n";

my %hsh_test = %{$hshs->{'%hsh_test'}}; #By Perl dereferencing.
my $hsh_test2 = $cnf->collection('%hsh_test'); #By CNF convention
my $hsh_test3 = $cnf->collection('%hsh_test');

#%{$hsh_test{'City'}}="New York";
$hsh_test2->{'Surname'}="Mason";
$hsh_test2->{'City'}="London";
$cnf->collection('%hsh_test')->{'Test'} ="check";
#we want both hashes to have same city
#eval($hsh_test{'City'} eq $hsh_test2{'City'});


print map {'<'.$_.'>'} keys %{$hsh_test2}, "\n";
print map {$_.'|'} keys %{$hsh_test3}, "\n";

print 'has Test key->'.$hsh_test3->{'Test'}, "\n";

print "Is reserved(INDEX)==".$cnf->isReservedWord('INDEX')."\n";
print "Is reserved(NOT)==".$cnf->isReservedWord('NOT')."\n";
print "Is reserved(MIGRATE)==".$cnf->isReservedWord('MIGRATE')."\n";

}




sub testAnons {

my $cnf = CNFParser->new($ENV{'PWD'}."/databaseAnonsTest.cnf");

# Test lifelog categories
my $v = $cnf->anons('CAT', undef);
if(!$v) {die "CAT is Missing!"}
print "\n--- CAT ---\n".$v;


my $cmd = $cnf->anons('list_cmd', $ENV{'PWD'});
print "CMD is:$cmd\n";
$cmd = `$cmd`;
print "Error failed system command!" if !$cmd;
#print "Listing:\n$exe\n";

print "\n--LIST OF ALL ANONS ENCOUNTERED---\n";
my %anons = $cnf->anons();
foreach my $k (keys %anons){
    print "Key->$k=", $anons{$k},"]\n";
}
eval((keys %anons) == 12) or die "Error annons count mismatch![".scalar(keys %anons)."]";

eval(length($cnf->constant('$HELP'))>0) or die 'Error missing multi-line valued constant property $HELP';

my $template = $cnf ->  template( 'MyTemplate', (
                                                'SALUTATION'=>'Mr',
                                                'NAME'=>'Prince Clington',
                                                'AMOUNT'=>"\$1,000,000",
                                                'CRITERIA'=>"Section 2.2 (Eligibility Chapter)"
                                )
                        );

print "\n--- TEMPLATE ---\n".$template;

### From the specs.
my $url = $cnf->anons('GET_SUB_URL',('tech','main.cgi'));
# $url now should be: https://www.tech.acme.com/main.cgi
eval ($url =~ m/https:\.*/)
or warn "Failed to obtain expected URL when querying anon -> GET_SUB_URL";
eval ($url eq 'https://www.tech.acme.com/main.cgi') or die "Error with: $url";


}


sub testRef{


    my @arr = [1..0];


    my @res1 = getArray();
    foreach my $v (@res1) {print $v.','}
    my @res2 = getArray();    shift @res2;
    my @res3 = @res2;
    print "\ncmp1:",(@res1 == @res2), "\n";
    print "cmp2:",(@res2 == @res3), "\n";
    foreach (@res2) {print $_.','}

    my @res4 = (1,2);
    my $res5 = [1,2];

    print "\ncmp1:",(@res4 == $res5), "\n";
    foreach my $v (@{$res5}) {print $v.','}

    my $res6 = \@res4;
    shift @res4;
    my @p = @{$res6};

    print "\np:@p\n", scalar(@p), "\n";

    foreach my $v (@p) {print $v.','}
    addRandowNumberTo(\@p);
    print "\n-List size ".scalar(@p)."-\n";
    foreach my $v (@p) {print $v.','}
     print "\n-List size ".scalar(@res4)."-\n";
    foreach my $v (@res4) {print $v.','}
    
}
sub getArray {return @{[1,2,3]}}
sub addRandowNumberTo { my $arr=shift; push @{$arr}, rand(100);
foreach my $v (@{$arr}) {print "[$v]\n"}
}



1;
