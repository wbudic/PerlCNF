package DataProcessorWorldCitiesPlugin;

use strict;
use warnings;

use feature qw(signatures);
use Scalar::Util qw(looks_like_number);


sub new ($class,$plugin){    
    return bless {}, $class
}

###
# Process config data to contain expected fields and data.
###
sub process ($self, $parser, $property) {

    my @data = $parser->data()->{$property};    
   
    for my $did (0 .. $#data){ 
        my @entry = @{$data[$did]};
        my $Spec_Size = 0;        
        my $mod = 0;
        # Cleanup header labels row.
        shift @entry;        
    }
    $parser->data()->{$property} = \@data;
}

###
# Process config data directly from a raw data file containing no Perl CNF tags.
# This is prefered way if your data is over, let's say 10 000 rows.
###

sub loadAndProcess ($self, $parser, $property) {

    my @data;    
    local $/ = undef;
    my $file = $parser->anon($property);
    open my $fh, '<', $file or die ("$!");
    foreach(split(/~\n/,<$fh>)){
        my @a;
        $_ =~ s/\\`/\\f/g;#We escape to form feed  the found 'escaped' backtick so can be used as text.
        foreach my $d (split /`/, $_){
            $d =~ s/\\f/`/g; #escape back form feed to backtick.
            $d =~ s/~$//; #strip dangling ~ if there was no \n
            my $t = substr $d, 0, 1;
            if($t eq '$'){
                my $v =  $d;         #capture spected value.
                $d =~ s/\$$|\s*$//g; #trim any space and system or constant '$' end marker.
                if($v=~m/\$$/){
                    $v = $self->{$d}; $v="" if not $v;
                }
                else{
                    $v = $d;
                }
                push @a, $v;
            }
            else{                            
                if($t =~ /^\#(.*)/) {#First is usually ID a number and also '#' signifies number.
                    $d = $1;#substr $d, 1;
                    $d=0 if !$d; #default to 0 if not specified.
                    push @a, $d
                }
                else{
                    push @a, $d;
                }
            }
        }  
        $data[@data]= \@a;
    }
    close $fh;
    $parser->data()->{$property} = \@data;
}

1;

=begin copyright
Programed by  : Will Budic
EContactHash  : 990MWWLWM8C2MI8K (https://github.com/wbudic/EContactHash.md)
Source        : https://github.com/wbudic/PerlCNF.git
Documentation : Specifications_For_CNF_ReadMe.md
    This source file is copied and usually placed in a local directory, outside of its repository project.
    So it could not be the actual or current version, can vary or has been modiefied for what ever purpose in another project.
    Please leave source of origin in this file for future references.
Open Source Code License -> https://github.com/wbudic/PerlCNF/blob/master/ISC_License.md
=cut copyright