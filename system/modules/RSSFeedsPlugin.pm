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

    my $CNFDateTime = $parser->now();
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
    $parser->addPostParseProcessor($self,'collectFeeds');
    $parser->data()->{$property} =\@data;    
}

sub collectFeeds($self,$parser) {
  my  $property = $self->{property};
  my %hdr;
  my @data = @{$parser->data()->{$property}};  
  for my $idx (0 .. $#data){
      my @col = @{$data[$idx]};
      if($idx==0){
        for my $i(0..$#col){
         $hdr{$col[$i]}=$i
        }
      }else{
          fetchFeed($col[$hdr{name}],$col[$hdr{url}],$col[$hdr{description}]);        
      }
  }
}

sub fetchFeed($name,$url,$description){
print "\n$name -> $url\n$description\n"
}

1;