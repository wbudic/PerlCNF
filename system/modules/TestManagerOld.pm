#!/usr/bin/perl -w
#
# Test Manager to make test case source code more readable and organised. 
# This is initial version, not supporting fall through and multiple test files and cases.
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
package TestManager;

use strict;
use warnings;

use Test::More;
use Test::Vars;

our $case;
our $case_cnt = 0; 

sub construct { my ($class, $self_args) = @_;
    die 'Arguments not passed -> {name=?:Name of this Manger., count=?:Current test count.}' if not $self_args;
    bless $self_args, $class;    
    return $self_args;
}

sub checkPackage {my ($self, $package)=@_;
    print "Checking package $package";
    vars_ok $package;
}
sub startCase {my ($self, $case)=@_;
    $self->{case}=$case;
    print "TestCase ".++$case_cnt.": Started -> $case\n"
}
sub info { my ($self, $info)=@_;
    print "TestCase ".$case_cnt.":info: $info\n"
}
sub endCase {my ($self, $package)=@_;
    print "TestCase $case_cnt: Ended -> $self->{case} PASSED!\n"
}
sub eval { my ($self, $a, $b, $c)=@_;
    if ($c) {my $swp = $a; $a = $b; $b= $c; $c = $swp}else{$c=""};
    die "$0 Test on ->". $self->{case} .", Failed!\n\neval(\n\$a->$a\n\$b->$b\n)\n" unless $a eq $b;
    print "\tTest " .++$self->{count}.": Passed -> $c [$a] equals [$b]\n"
}
sub finish {my $self = shift;
    print "\nALL TESTS HAVE PASSED for ". $self->{name}. " Totals ->  test cases: ".$case_cnt. " test count: ".$self->{count}."\n";
    done_testing;
}
1;