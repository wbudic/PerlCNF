package RSSFeedsPlugin;

use strict;
use warnings;

use feature qw(signatures);
use Scalar::Util qw(looks_like_number);
use Time::Piece;
use Clone qw(clone);
use constant VERSION => '1.0';

sub new ($class, $plugin){
    my $settings;
    if($plugin){
       $settings = clone $plugin; #clone otherwise will get hijacked with blessings.
    }
    return bless $settings, $class
}

###
# Process config data to contain expected fields.
###
sub process ($self, $parser, $property) {    

    my $timestamp  = Time::Piece->new();
    my $CNFDateTime = $timestamp->strftime('%Y-%m-%d %H:%M:%S %Z');    
    my @data = @{$parser->data()->{$property}};
    for my $idx (0 .. $#data){
        my @col = @{$data[$idx]};
        if($idx>0){
            $col[0] = $idx+1;
            $col[4] = $CNFDateTime;
        }else{            
            $col[4]='last_updated';
        }
        $data[$idx]=\@col;
    }
    $parser->data()->{$property} =\@data
}
sub zero_prefix ($times, $val) {
    if($times>0){
        return '0'x$times.$val;
    }else{
        return $val;
    }
}
sub matchType($type, $val, @rows) {
    if   ($type==1 && looks_like_number($val)){return 1}
    elsif($type==2){
          if($val=~/\d*\/\d*\/\d*/){return 1}
          else{
               return 1;
          }
    }
    elsif($type==3){return 1}
    return 0;
}

1;