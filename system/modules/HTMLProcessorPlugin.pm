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
    my $header = $parser->{'HTTP_HEADER'};
    my $tree = $parser->anon($property);
    die "Tree property '$property' is not available!" if(!$tree or ref($tree) ne 'CNFNode');

try{

    my $title = $tree -> {'Title'};
    my $link  = $tree -> {'HEADER'};
     
    my ($bfHDR,$style);
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
            $style = "<style>\n".  @$ps[0]-> val()."</style>" if($ps);
       }
       
       delete $tree -> {'HEADER'};       
    }

    my $buffer = qq($header
<head>
<title>$title</title>
$bfHDR
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
$style
</head>
);

    $buffer .= "<body>\n";
        foreach 
        my $node($tree->nodes()){  
        my $bf   = build($node);     
        $buffer .= "$bf\n" if $node;
        }
    $buffer .= "</body>\n</html>\n";

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
    if(isParagraphName($node->{'name'})){
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
    }elsif( lc($node->{'name'}) eq 'img'){
        $bf .= "\t\t<img".placeAttributes($node)."/>\n";
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