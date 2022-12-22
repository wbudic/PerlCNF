package HTMLProcessorPlugin;

use strict;
use warnings;
use Syntax::Keyword::Try;
use Exception::Class ('HTMLProcessorPluginException');
use feature qw(signatures);
use Scalar::Util qw(looks_like_number);
use Date::Manip;


sub new ($class, $fields={Language=>'English',DateFormat=>'US'}){      

    if(ref($fields) eq 'REF'){
       warn "Hash reference required as argument for fields!"
    }
    my $lang =   $fields->{'Language'};
    my $frmt =   $fields->{'DateFormat'};
    Date_Init("Language=$lang","DateFormat=$frmt");    
   
    return bless $fields, $class
}

###
# Process config data to contain expected fields and data.
###
sub convert ($self, $parser, $property) {
    my ($bfHDR,$style,$title, $link, $body_attrs)=("","","","","");
     
    my $tree = $parser->anon($property);
    die "Tree property '$property' is not available!" if(!$tree or ref($tree) ne 'CNFNode');

try{
    my $header = $parser->{'HTTP_HEADER'};$header = "" if !$header;
    $title = $tree -> {'Title'};
    $link  = $tree -> {'HEADER'};
    $body_attrs .= " ". $tree -> {'Body'} if exists $tree -> {'Body'};
    if($link){
       if(ref($link) eq 'CNFNode'){
            my $arr = $link->find('CSS/@@');
            foreach (@$arr){
                $bfHDR .= qq(\t<link rel="stylesheet" type="text/css" href="$_" />\n);
            }
            $arr = $link->find('JS/@@');
            foreach (@$arr){
                $bfHDR .= qq(\t<script src="$_"></script>\n);
            } 
            my $ps = $link  -> find('STYLE');
            $style = "<style>\n".  $ps -> val()."</style>" if($ps);
       }
       
       delete $tree -> {'HEADER'};       
    }

    my $buffer = qq($header
<!DOCTYPE html>
<head>
<title>$title</title>
$bfHDR
$style
</head>
);
    
    $buffer .= qq(<body$body_attrs><div class="main">
                            <div class="divTableBody">);
        foreach 
        my $node($tree->nodes()){  
        my $bf   = build($node);     
        $buffer .= "$bf\n" if $node;
        }
    $buffer .= "</div></div>\n</body>\n</html>\n";

    $parser->data()->{$property} = \$buffer;
}catch{
        HTMLProcessorPluginException->throw(error=>$@ ,show_trace=>1);
}
}
#

###
# Builds the html version out of an CNFNode.
###
sub build {
    my $node = shift;
    my $bf;
    my $name = lc $node->{'name'};
    if(isParagraphName($name)){
        $bf .= "\t<div".placeAttributes($node).">\n<div>";
            foreach my $n($node->nodes()){
                if($n->{'name'} ne '#'){
                    my $b = build($n);     
                    $bf .= "$b\n" if $b;
                }
            }
            if($node->{'#'}){
                my $v = $node->val();
                $v =~ s/\n\n+/\<\/br>\n/gs;
                $bf .= "\t<div>\n\t<p>\n".$v."</p>\n\t</div>\n"; 
            }
        $bf .= "\t</div>\t</div>"
    }elsif( $name eq 'row' || $name eq 'cell' ){
        $bf .= "\t<div class=\"$name\"".placeAttributes($node).">\n";
            foreach my $n($node->nodes()){
                if($n->{'name'} ne '#'){
                    my $b = build($n);     
                    $bf .= "$b\n" if $b;
                }
            }
        $bf .= $node->val()."\n" if $node->{'#'};   
        $bf .= "\t</div>"
    }elsif( $name eq 'img' ){
        $bf .= "\t\t<img".placeAttributes($node)."/>\n";
    }elsif($name eq 'list_images'){
        my @images = glob($node ->{'path'}.'*.*');
        foreach my $file(@images){
            ($file=~/configs\/docs\/(.*)\.cnf$/);
            $bf .= qq(<div class='row'><div class='cell'><img srv="$file" with='120' height='120'>$1</a><br>\n);
            $bf .= qq(<a href="$file">$1</a><br>\n</div></div>\n);
        }
    
    }else{
        $bf .= "\t<".$node->{'name'}.placeAttributes($node).">\n";
            foreach my $n($node->nodes()){                 
                    my $b = build($n);
                    $bf .= "$b\n" if $b;        
            }
        $bf .= $node->val()."\n" if $node->{'#'};
        $bf .= "\t</".$node->{'name'}.">\n";

    }
    return $bf;
}
#


sub placeAttributes {
    my $node = shift;
    my $ret  = "";
    my @attr = $node -> attributes();
    foreach (@attr){
        if(@$_[0] ne '#' && @$_[0] ne 'name'){
           if(@$_[1]){
              $ret .= " ".@$_[0]."=\"".@$_[1]."\"";
           }else{ 
              $ret .= " ".@$_[0]." ";
           }
        }
    }
    return $ret;
}

sub isParagraphName {
    my $name = shift;
    return $name eq 'p' || $name eq 'paragraph' ? 1 : 0
}



1;