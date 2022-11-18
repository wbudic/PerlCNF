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

    use Hash::Util qw(lock_hash lock_keys lock_value unlock_value bucket_stats_formatted);
    #our %HAS = (name=>"Unknown", value=>'0', rnd=>'0', cnt=>'0');
    state %defaults = (name=>"Unknown", value=>0, rnd=>0, cnt=>0);

    our $field = 'george';
    sub field(){return $field}
    
    sub construct {
        my ($pck, $args, $fld) = @_;       
        my %join = %defaults;
        $field = $fld if $fld;
        @join{keys %$args} = values %$args;        
        my $r =  bless \%join, $pck;
        lock_hash(%join);
        unlock_value(%join, 'name');
        unlock_value(%join, 'value');
        unlock_value(%join,'cnt');
        unlock_value(%join,'rnd');
        return $r
    }
    sub name  {my ($self, $set)=@_;$self->{NAME}=$set if $set; return $self->{NAME}}
    sub value {my ($self, $set)=@_;$self->{VALUE}=$set if $set; return $self->{VALUE}}

    sub setSeed  {my ($self, $set)=@_;$self->{rnd} = $set;return}

    sub increaseCounter { return ++shift->{cnt}}
    sub currentCounter(){ return shift->{cnt}}
    sub stats(){return bucket_stats_formatted(shift)}
};

my $pck1 = PV->construct({NAME=>"tester", VALUE=>1, cnt=>10});

print "pck1.name:".  $pck1->name(), "\n";
print "pck1.value:". $pck1->value(), "\n";
print "pck1.field:". $pck1->field(), "\n";
print $pck1->stats();

foreach(1..10){
    print "pck1.cnt[$_]:". $pck1->increaseCounter(), "\n";
}
print "pck1.cnt:". $pck1->currentCounter(), "\n";

my $pck2 = PV->construct({name=>"tester2", cnt=>-10},'michael');
print "pck2.name:".  $pck2->name(), "\n";
print "pck2.value:". $pck2->value(), "\n";

print "PV.field:". PV::field(), "\n";
#$pck2->{'name2'}='dynamic';
my $pck3 = PV->construct();
$pck3->{NAME}='new_name';
$pck3->{NAME}='rename';
print "pck3.name:".  $pck3->{'name'}, "\n";
#print "pck2.name2:".  $pck2->{'name2'}, "\n";
print "pck1.field:". $pck1->field(), "\n";
print "pck2.field:". $pck2->field(), "\n";


foreach(1..10){
    print "pck2.cnt[$_]:". $pck2->increaseCounter(), "\n";
}
print "pck2.cnt:". $pck2->currentCounter(), "\n";
print "pck1.inc_cnt:". $pck1->increaseCounter(), "\n";
print "pck2.inc_cnt:". $pck2->increaseCounter(), "\n";


my ($j,$i, $random,@pv);
for my $i(1..100){
    $pv[$i] = PV->construct({name=>sprintf("PRP%03d", $i), value=>int($i), shit=>"me not"});
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
    #printf("%03d:", $i); 
    $pv[++$j]->setSeed($random);
    print $pv[$j]->name(), "=",  $pv[$j]->value(), ":random[$random] rnd:",$pv[$j]{'rnd'},"\n";
    
}


my @keys = sort { $a <=> $b } keys %unique;
print join(", ", @keys), "\n";



1;
