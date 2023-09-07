package RSSFeedsPlugin;

use strict;
use warnings;

use feature qw(signatures);
use Scalar::Util qw(looks_like_number);
use Syntax::Keyword::Try;
use Clone qw(clone);
use Capture::Tiny 'capture_stdout';
use FileHandle;
use XML::RSS::Parser;
use Date::Manip::Date;
use LWP::Protocol::https; #<-- 20230829  This  module some times, will not be auto installed for some reason.
use LWP::Simple;

use Benchmark;

use constant VERSION => '1.0';

# require CNFNode;
# require CNFDateTime;

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
         my $name = $col[$hdr{name}];
         my $tree =  fetchFeed($self, $name,$col[$hdr{url}],$col[$hdr{description}]);
         if(ref($$tree) eq 'CNFNode'){
            my $output_local = getOutputDir($self);
            my $fname = $name; $fname =~ s/[\s|\W]/_/g; $fname = ">$output_local"."tree_feed_$fname.cnf";
            my %rep = %{$parser -> data()};
               $rep{$name} = $tree;
            my $FH = FileHandle->new($fname);
            my $root = $$tree;
            print $FH $root->toScript();
            close $FH;
         }
      }
  }
}

sub getOutputDir($self){
    my  $output_local = $self->{OUTPUT_DIR};
    if ($output_local){
        $output_local.= '/';
        mkdir $output_local unless -d $output_local;
    }
    return $output_local
}

sub fetchFeed($self,$name,$url,$description){

    my $fname = $name; $fname =~ s/[\s|\W]/_/g; $fname = "rss_$fname.rdf";
    if(CNFParser::_isTrue($self->{RUN_FEEDS})){
        if(-e $fname) {
            my $now   = new Date::Manip::Date -> new_date(); $now->parse("today");
            my $fdate = new Date::Manip::Date;
            my $fsepoch = (stat($fname))[9]; $fdate->parse("epoch $fsepoch"); $fdate->parse("3 business days");
            my $delta = $fdate->calc($now);
            if($now->cmp($fdate)>0){
                unlink $fname;
            }

        }
        unless ( -e $fname ) {
            try{
                print "Fetching: $fname -> $url ...";
                my  $res = getstore($url, $fname);
                if ($res == 200){
                    print "\e[2Adone!\n"
                }else{
                    print "\e[2AError<$res>!\n"
                }
            }catch{
                print "Error: $@.\n";
                return;
            }
        }
    }

    my ($MD, $tree, $brew,$bench);
    my $console     = CNFParser::_isTrue($self->{OUTPUT_TO_CONSOLE});
    my $convert     = CNFParser::_isTrue($self->{CONVERT_TO_CNF_NODES});
    my $markup      = CNFParser::_isTrue($self->{OUTPUT_TO_MD});
    my $benchmark   = CNFParser::_isTrue($self->{BENCHMARK});
    my $output_local= getOutputDir($self);

    my $parser = XML::RSS::Parser->new;
    my $fh = FileHandle->new($fname);
    my $t0 = Benchmark->new;
    my $feed = $parser->parse_file($fh);
    my $t1 = Benchmark->new;
    my $td = timediff($t1, $t0);
    $bench = "The XML parser for $fname took:\t".timestr($td)."\n" if $benchmark;

    print "Parsing: $fname\n";

    if(!$feed){
        print "Failed to parse RSS feed:$name file:$fname\n";
        return
    }

my $buffer = capture_stdout {
        if($console){
            print 'x'x60,"\n";
            print $feed->query('/channel/title')->text_content, " [ Items: ",$feed->item_count, " ]\n";
            print 'x'x60,"\n\n";
        }else{
            if($markup){
            $fname = ">$output_local"."rss_$name.md";
            $MD = FileHandle->new($fname);
            #binmode($MD, ":encoding(UTF-8)");
            print $MD "# ",$feed->query('/channel/title')->text_content, "\n";
            print $MD "\n   $description\n\n";
            print $MD "* Feed: [$name]($url)\n";
            print $MD "* Items: ",$feed->item_count, "\n";
            print $MD "* Date: ", $self->{date} -> toSchlong(), "\n\n";
            }
        }
        if($convert){
                    my $published = CNFDateTime->new()->toTimestamp();
                    my $expires   = new Date::Manip::Date -> new_date(); $expires->parse("7 business days");
                       $expires   =  $expires->printf(CNFDateTime::FORMAT());
                    my $fnm = $name; $fnm =~ s/[\s|\W]/_/g;
                    my $feed = CNFNode -> new({'_'=>'Feed',Published=>$published, Expires=>$expires,File => $output_local."tree_feed_$fnm.cnf"});
                    $tree =    CNFNode -> new({'_'=>'CNF_FEED',Version=>'1.0', Release=>'1'});
                    $brew =    CNFNode -> new({'_'=>'Brew'});
                    $tree -> add($feed)->add($brew);
        }
        $t0 = Benchmark->new;
        my $items_cnt =0;
        foreach my $item
                    ( $feed->query('//item') ) {
            my $title = $item->query('title')->text_content;
            my $date  = $item->query('pubDate');
            my $desc  = $item->query('description')->text_content;
            my $link  = $item->query('link')->text_content;
            my $CNFItm; $items_cnt++;
            if(!$date) {
                $date  = $item->query('dc:date');
            }
            $date = $date->text_content;
            $date = CNFDateTime::_toCNFDate($date, $self->{TZ})->toTimestampShort();
            if($console){
                    print "Title : $title\n";
                    print "Link  : $link\n";
                    print "Date  : $date\n";
            }else{
                    if($markup){
                    print $MD "\n## $title\n\n";
                    print $MD "* Link : <$link>\n";
                    print $MD "* Date : $date\n\n";
                    }

            }
            if($convert){
                $CNFItm =  CNFNode -> new({
                                            '_'     => 'Item',
                                            Title   => $title,
                                            Link    => $link,
                                            Date    => $date
                                });
                $brew->add($CNFItm);
            }
            if (length($desc)>0){
                if($console){
                            print '-'x20,"\n";
                            print $desc;
                            print "\n" if $desc !~ /\s$/
                }else{
                            print $MD "   $desc\n" if $markup;
                }
                if($convert){
                $CNFItm->add(CNFNode -> new({'_'=>"Description",'#'=>\$desc}));
                }
            }
            if($console){ print '-'x40,"\n";
            }else{
                print $MD "\n---\n" if $markup
            }
        }
        $t1 = Benchmark->new;
        $td = timediff($t1, $t0);
        #TODO: XML query method is very slow, we will have to resort and test the CNFParser->find in comparance.
        #      Use XML RSS only to fetch, from foreing servers the feeds, and translate to CNFNodes.
        $bench .= "The XML QUERY(//Item)  for $fname items($items_cnt) took:\t".timestr($td)."\n" if $benchmark;

        if($console){
            print 'X'x20, " ", $feed->query('/channel/title')->text_content." Feed End ",'X'x20,"\n\n";
        }else{
             $MD->close() if $markup
        }
    };
    print $buffer if $console;
    print $bench if $benchmark;
    return \$tree if $convert;
    return \$buffer;
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