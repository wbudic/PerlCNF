package RSSFeedsPlugin;

use strict;
use warnings;

use feature qw(signatures);
use Scalar::Util qw(looks_like_number);
use Syntax::Keyword::Try;
use Clone qw(clone);
use XML::RSS::Parser;
use FileHandle;
use LWP::Simple;

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
    #$url = "http://search.cpan.org/uploads.rdf";

    my $fname = $name; $fname =~ s/[\W\s]/_/g; $fname = "rss_$name.rdf";
    unless ( -e $fname ) {
        try{
            print "Fetching: $fname -> $url ...";
            my  $res = getstore($url,$fname);
            if ($res == 200){
                print "done!\n"
            }else{
                print "error<$res>!\n"
            }
        }catch{
            print $@."\n";
            return;
        }
    }
    my $parser = XML::RSS::Parser->new;
    my $fh = FileHandle->new($fname);
    my $feed = $parser->parse_file($fh);

    if(!$feed){
        print "Failed to parse RSS feed:$name file:$fname\n";
        return
    }

    print 'x'x60,"\n";
    print $feed->query('/channel/title')->text_content, " [ Items: ",$feed->item_count, " ]\n";
    print 'x'x60,"\n\n";

    foreach my $item ( $feed->query('//item') ) {
        my $title = $item->query('title')->text_content;
        my $date  = $item->query('pubDate');
        my $desc  = $item->query('description')->text_content;
        my $link  = $item->query('link')->text_content;
        if(!$date) {
            $date  = $item->query('dc:date');
        }
        $date = $date->text_content;
        print "Title : $title\n";
        print "Link  : $link\n";
        print "Date  : $date\n";
        if (length($desc)>0){
            print '-'x20,"\n";
            print $desc;
            print "\n" if $desc !~ /\s$/
        }
        print '-'x40,"\n";

    }
    print 'X'x20, " ", $feed->query('/channel/title')->text_content." Feed End ",'X'x20,"\n\n";
}

1;