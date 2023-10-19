package RSSFeedsPlugin;

use strict;
use warnings;
no warnings qw(experimental::signatures);
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

CNFParser::import();

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
    my $cgi  = $parser->const('CGI');
    $self->{date} = now();
    for my $idx (0 .. $#data){
        my @col = @{$data[$idx]};
        if($idx>0){
            $col[0] = $idx+1;
            $col[4] = $self-> {date} -> toTimestamp();
        }else{
            $col[4] = 'last_updated';
        }
        $data[$idx]=\@col;
    }
    if($cgi&&$cgi->param('action') eq 'list'){
       my $page = '<div class="feed"><h2>List Of Feeds</h2><ol>';
       for my $idx (1 .. $#data){
           my @col = @{$data[$idx]};
           $page .= qq|<li><span style="border: 1px solid black; padding: 5px; padding-bottom: 0px;">
           <a onclick="return fetchFeed('$col[1]')" style="cursor: pointer;"> <b>$col[1]</b> </a></span>
            &nbsp;&nbsp;[ $col[4] ]<dt style="padding:10px;">$col[3]</dt></li>\n|;
       }
       $page .= '</ol></div>';
       $parser->data()->{PAGE} = \$page
    }else{
       $parser->addPostParseProcessor($self,'collectFeeds');
    }
    $parser->data()->{$property} = \@data
}

sub collectFeeds($self, $parser) {
  my $property = $self->{property};
  my %hdr;
  my @data = @{$parser->data()->{$property}};
  my $cgi  = $parser->const('CGI');
  my $page;
  my $feed = $cgi->param('feed') if $cgi;
  $parser->log("Feed request:$feed");
  for my $idx (0 .. $#data){
       my @col = @{$data[$idx]};
      if($idx==0){
        for my $i(0..$#col){ # Get the matching table column index names as scripted.
               $hdr{$col[$i]} = $i
        }
      }else{
         my $name = $col[$hdr{Name}]; #<- Now use the column names as coded, if names in script are changed, you must change here.
         next if($feed && $feed ne $name);
         my $tree =  fetchFeed($self, $name, $col[$hdr{URL}], $col[$hdr{Description}]);
         $parser->log("Fetched feed:".$name);
         if($tree && ref($$tree) eq 'CNFNode'){
            if(not isCNFTrue($self->{CNF_TREE_LOADED}) && isCNFTrue($self->{CNF_TREE_STORE})){
               my $output_local = getOutputDir($self);
               my $fname = $name; $fname =~ s/[\s|\W]/_/g; $fname = ">$output_local"."tree_feed_$fname.cnf";
               my $FH = FileHandle->new($fname);
               my $root = $$tree;
               print $FH $root->toScript();
               close $FH;
               $parser->addTree($name, $tree);
            }
            if(isCNFTrue($self->{CONVERT_CNF_HTML})){
               $page .= _treeToHTML($tree);
               $page .=qq(<a class="ui-button ui-corner-all ui-widget" onclick="return fetchFeeds('#feeds_bottom')">RSS Feeds</a>&nbsp;[<a href="#feed_top">To Top Of Feed</a>]
               <div id="feeds_bottom" style ="margin: 5px;padding:0;visibility:hidden"><br></div>
               )
            }
         }else{
            $parser-> warn("Feed '$name' bailed to return a CNFNode tree.")
         }
      }
  }
  $parser->data()->{PAGE} = \$page if $page;
}
### PerlCNF TREE to HTML Conversion Routine, XML based RSS of various Internet feeds convert to PerlCNF previously.
sub _treeToHTML($tree){
    my $root = $$tree;
    my $feed = $root->node('Feed');
    my $brew = $root->node('Brew');
    my ($Title, $Published,$URL,$Description) = $feed -> array('Title','Published','URL','#');
    my $bf = qq(
        <div class="feed">
        <div class="feeds_hdr">
            <div class="feed_title"><h2>$Title</hd></div>
            <div class-"feed_lbl"><div class="feed_hdr_lbl">Published:</div>$Published</span></div>
            <div class-"feed_hdr"><div class="feed_hdr_lbl"><span style="text-align:right;width:inherit;">URL:&nbsp;</span></div>)._htmlURL($URL).qq(</div>
            <div class-"feed_hdr"><p>$Description</p></div>
        </div>
        </div>
    );
    my $alt = 0;
    foreach
        my $item(@{$brew->items()}){
        next if $item->name() ne 'Item';
        my ($Title,$Link,$Date) = $item -> array('Title','Link','Date');
        my $Description         = $item -> node('Description') -> val();
           $Description =~ s/<a/<a target="feed"/gs if $Description;
        $bf.= qq(
            <div class="feed">
            <div class="feeds_item_$alt">
                <div class="feed_title"><div class="feed_lbl">Title:</div>$Title</div>
                <div class="feed_link"><div class="feed_lbl">Link:</div>)._htmlURL($Link).qq(</div>
                <div class="feed_Date"><div class="feed_lbl">Date:</div>$Date<div><hr></div></div>
                <div class="feed_desc"><span>$Description<span></div>
            </div>
            </div>
        );
        $alt = $alt?0:1;
    }
    return $bf . '<hr class="feeds">'
}

sub _htmlURL {
    my $link = shift;
    return qq(<a class="feed_link" href="$link" target="feed">$link</a>)
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

    my ($MD, $tree, $brew,$bench);
    my $console     = isCNFTrue($self->{OUTPUT_TO_CONSOLE});
    my $convert     = isCNFTrue($self->{CONVERT_TO_CNF_NODES}); #<--_ If true,
    my $stored      = isCNFTrue($self->{CNF_TREE_STORE});       #<-\_ Will use a fast stashed local CNF tree instead of the XML::RSS::Parser.
    my $markup      = isCNFTrue($self->{OUTPUT_TO_MD});
    my $benchmark   = isCNFTrue($self->{BENCHMARK});
    my $output_local= getOutputDir($self);
    my $fname = $name; $fname =~ s/[\s|\W]/_/g;

    $fname = $output_local."rss_$fname.rdf";

    if(isCNFTrue($self->{RUN_FEEDS})){
        if(-e $fname) {
            my $now   = new Date::Manip::Date -> new_date(); $now->parse("today");
            my $fdate = new Date::Manip::Date;
            my $fsepoch = (stat($fname))[9]; $fdate->parse("epoch $fsepoch"); $fdate->parse("3 business days");
            my $delta = $fdate->calc($now);
            $self->{CNF_TREE_LOADED} = 0;
            if($now->cmp($fdate)>0){
                unlink $fname;
            }else{
                my $cnf_fname = $name; $cnf_fname =~ s/[\s|\W]/_/g;
                $cnf_fname =  $output_local."tree_feed_$cnf_fname.cnf";
                if($convert && $stored && -e $cnf_fname){
                   $self->{CNF_TREE_LOADED} = 1 if $_ = CNFParser -> new($cnf_fname,{DO_ENABLED => 1}) -> getTree('CNF_FEED');
                   return $_;
                }
            }
        }
        unless ( -e $fname ) {
            try{
                print "Fetching: $fname -> [$url] ...";
                my  $res = getstore($url, $fname);
                if ($res == 200){
                    print "done!\n"
                }else{
                    print "Error<$res>!\n";
                    `curl $url -o $fname`
                }
            }catch{
                print "Error: $@.\n";
                return;
            }
        }
    }

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

my  $buffer = capture_stdout {
        my $Title = $feed->query('/channel/title')->text_content;
        if($console){
            print 'x'x60,"\n";
            print $Title, " [ Items: ",$feed->item_count, " ]\n";
            print 'x'x60,"\n\n";
        }else{
            if($markup){
            $fname = ">$output_local"."rss_$name.md";
            $MD = FileHandle->new($fname);
            #binmode($MD, ":encoding(UTF-8)");
            print $MD "# ", $Title, "\n";
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
                    my $Title = $feed->query('/channel/title')->text_content;
                    my $feed = CNFNode -> new({'_'=>'Feed',Title => $Title, Published=>$published, Expires=>$expires,
                                                           File  => $output_local."tree_feed_$fnm.cnf", '#'=>$description,
                                                           URL=>$url});
                    $tree =    CNFNode -> new({'_'=>'CNF_FEED',Version=>'1.0', Release=>'1'});
                    $brew =    CNFNode -> new({'_'=>'Brew'});
                    $tree -> add($feed)->add($brew);
        }
        $t0 = Benchmark->new;
        my $items_cnt =0;
        foreach my $item
                    (   $feed->query('//item') ) {
            my $title = $item->query('title')->text_content;
            my $date  = $item->query('pubDate');
            my $desc  = $item->query('description')->text_content;
            my $link  = $item->query('link')->text_content;
            my $CNFItm; $items_cnt++;
            if(!$date) {
                $date  = $item->query('dc:date');
            }
            if(!$date){
                print "Feed pub date item error with:$title";
                next
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

1; # <-- The score I get for using multipe functionality returns, I know. But if can swat 7 flies in one go, why not do it?

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