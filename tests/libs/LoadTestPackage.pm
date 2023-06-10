package LoadTestPackage;
use strict;
use warnings;

sub new {
    my $class = shift;
    return  bless {'Comming from where?' => 'out of thin air!'},$class
}

sub tester{
return "Hello World!";
}


1;
