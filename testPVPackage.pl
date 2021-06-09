#!/usr/bin/perl -w
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
use v5.10;
use strict;
use warnings;
use Try::Tiny;

package PV {
    
    sub create {
        my ($pck,$args) = @_;
        state $cnt = $args->{cnt};
        bless { 
                       name => $args->{name}, 
                       value => $args->{value},
                       rnd =>0,
                       cnt =>$cnt                       
         }, $pck;
    }
    sub name  {my ($self, $set)=@_;$self->{name}=$set if $set;$self->{name}}
    sub value {my ($self, $set)=@_;$self->{value}=$set if $set;$self->{value}}

    sub setSeed  {my ($self, $set)=@_;$self->{rnd} = $set}

    sub increaseCounter {++shift->{cnt}}
    sub currentCounter(){shift->{cnt}}
};

my $pck1 = PV->create({name=>"tester", value=>1, cnt=>10});

print "pck1.name:".  $pck1->name(), "\n";
print "pck1.value:". $pck1->value(), "\n";

foreach(1..10){
    print "pck1.cnt[$_]:". $pck1->increaseCounter(), "\n";
}
print "pck1.cnt:". $pck1->currentCounter(), "\n";

my $pck2 = PV->create({name=>"tester2", cnt=>-10});
print "pck2.name:".  $pck2->name(), "\n";
print "pck2.value:". $pck2->value(), "\n";

foreach(1..10){
    print "pck2.cnt[$_]:". $pck2->increaseCounter(), "\n";
}
print "pck2.cnt:". $pck2->currentCounter(), "\n";
print "pck1.inc_cnt:". $pck1->increaseCounter(), "\n";
print "pck2.inc_cnt:". $pck2->increaseCounter(), "\n";

my ($i, $random,@pv) =();
for my $i(1..100){
    $pv[$i] = PV->create({name=>"PRP$i", value=>$i, shit=>"me not"});
}
my %unique = ();
for my $i(1..100){
    while($i<150){
        $random = int(rand(10001) + 1);
        if(exists $unique{$random}){
           $unique{$random} = $unique{$random}++;
           next;
        }
        $unique{$random} = 1;
        last; 
    }
    printf("%03d:", $i); 
    print $pv[$i]->name(), "=",  $pv[$i]->value(), "random[$random]\n";
    $pv[$i]->setSeed($random);
}


my @keys = sort { $a <=> $b } keys %unique;
print join(", ", @keys), "\n";



1;
