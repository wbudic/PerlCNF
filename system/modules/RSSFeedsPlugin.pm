package RSSFeedsPlugin;

use strict;
use warnings;

use feature qw(signatures);
use Scalar::Util qw(looks_like_number);
use Syntax::Keyword::Try;
use Clone qw(clone);
use Capture::Tiny 'capture_stdout';
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
    my @data = @{$parser->data()->{$property}};
    $self->{date} = $parser->now();
    for my $idx (0 .. $#data){
        my @col = @{$data[$idx]};
        if($idx>0){
            $col[0] = $idx+1;
            $col[4] = $self->{date} -> toTimestamp();
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
          fetchFeed($self,  $col[$hdr{name}],$col[$hdr{url}],$col[$hdr{description}]);
      }
  }
}

sub fetchFeed($self,$name,$url,$description){

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
    
my $MD;
my $console=$self->{output_console};
my $buffer = capture_stdout{
if($console){
    print 'x'x60,"\n";
    print $feed->query('/channel/title')->text_content, " [ Items: ",$feed->item_count, " ]\n";
    print 'x'x60,"\n\n";
}else{
    $fname = ">rss_$name.md";
    $MD = FileHandle->new($fname);
    print $MD "# ",$feed->query('/channel/title')->text_content, "\n";
    print $MD "\n   $description\n\n";
    print $MD "* Feed: [$name]($url)\n";
    print $MD "* Items: ",$feed->item_count, "\n";
    print $MD "* Date: ", $self->{date} -> toSchlong(), "\n\n";
}
    foreach my $item 
                  ( $feed->query('//item') ) {
        my $title = $item->query('title')->text_content;
        my $date  = $item->query('pubDate');
        my $desc  = $item->query('description')->text_content;
        my $link  = $item->query('link')->text_content;
        if(!$date) {
            $date  = $item->query('dc:date');
        }
        $date = $date->text_content;
if($console){        
        print "Title : $title\n";
        print "Link  : $link\n";
        print "Date  : $date\n";
}else{

        print $MD "\n## $title\n\n";
        print $MD "* Link : <$link>\n";
        print $MD "* Date : $date\n\n";

}
        if (length($desc)>0){
if($console){                    
            print '-'x20,"\n";
            print $desc;
            print "\n" if $desc !~ /\s$/
}else{
            print $MD "   $desc\n";
}
        }
if($console){ print '-'x40,"\n";
}else{
    print $MD "\n---\n";
}
    }
if($console){            
    print 'X'x20, " ", $feed->query('/channel/title')->text_content." Feed End ",'X'x20,"\n\n";
}else{
    close $MD;
}
}

}

1;

=begin scrap

# Remote PerlCNF Feed Format, opposed to RSS XML, would look like this:
<<CNF_FEED<TREE>
    Version  = 1.0
    Release  = 1
    <Feed<
        Published: 2023-12-15         
        Expires: 2023-12-30    
        URL: https://lalaland.com/feeds.cgi
    >Feed>    
    [brew[
        [item[
            Title:
            Date:
            Link:
            [Description[
            [#[

            ]#]
            ]Description]
        ]item]
        [item[
            Title:
            Date:
            Link:
            [Description[
            [#[

            ]#]
            ]Description]
        ]item]
    ]brew]
>>

=cut scrap

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