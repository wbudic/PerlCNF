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
    my ($bfHDR,$style,$jscript,$title, $link, $body_attrs, $header)=("","","","","","","");
    $self->{CNFParser} = $parser;
     
    my $tree = $parser->anon($property);
    die "Tree property '$property' is not available!" if(!$tree or ref($tree) ne 'CNFNode');

try{
    $header = $parser-> {'HTTP_HEADER'} if exists $parser->{'HTTP_HEADER'};
    $title  = $tree  -> {'Title'} if exists $tree->{'Title'};
    $link   = $tree  -> {'HEADER'};
    $body_attrs .= " ". $tree -> {'Body'} if exists $tree -> {'Body'};
    if($link){
       if(ref($link) eq 'CNFNode'){
            my $arr = $link->find('CSS/@@');
            foreach (@$arr){
                my $v = $_->val();
                $bfHDR .= qq(\t<link rel="stylesheet" type="text/css" href="$v" />\n);
            }
            $arr = $link->find('JS/@@');
            foreach (@$arr){
                my $v = $_->val();
                $bfHDR .= qq(\t<script src="$v"></script>\n);
            } 
            my $ps = $link  -> find('STYLE');
            $style = "\n<style>\n".  $ps -> val()."</style>" if($ps); 
            $ps = $link  -> find('JAVASCRIPT');
            $jscript = "\n<script>\n".  $ps -> val()."</script>" if($ps);
       }
       
       delete $tree -> {'HEADER'};       
    }

    my $buffer = qq($header
<!DOCTYPE html>
<head>
<title>$title</title>$bfHDR $style $jscript
</head>
);
    
    $buffer .= qq(<body$body_attrs>\n<div class="main"><div class="divTableBody">\n);
        foreach 
        my $node($tree->nodes()){  
        my $bf   = build($node);     
        $buffer .= "$bf\n" if $node;
        }
    $buffer .= "\n</div></div>\n</body>\n</html>\n";

    $parser->data()->{$property} = \$buffer;

}catch{
        HTMLProcessorPluginException->throw(error=>$@ ,show_trace=>1);
}
}
#

###
# Builds the html version out of a CNFNode.
# CNFNode with specific tags here are converted also here, 
# those that are out of the scope for normal standard HTML tags.
# i.e. HTML doesn't have row and cell tags. Neither has meta links syntax.
###
sub build {
    my $node = shift;
    my $tabs = shift; $tabs = 1 if !$tabs;
    my $bf;
    my $name = lc $node->name();
    if(isParagraphName($name)){
        $bf .= "\t"x$tabs."<div".placeAttributes($node).">\n"."\t"x$tabs."<div>";
            foreach my $n($node->nodes()){
                if($n->{'_'} ne '#'){
                    my $b = build($n, $tabs+1);     
                    $bf .= "$b\n" if $b;
                }
            }
            if($node->{'#'}){
                my $v = $node->val();
                $v =~ s/\n\n+/\<\/br>\n/gs;
                $bf .= "\t<div>\n\t<p>\n".$v."</p>\n\t</div>\n"; 
            }
        $bf .= "\t</div>\t</div>\n"
    }elsif( $name eq 'row' || $name eq 'cell' ){
        $bf .=  "\t"x$tabs."<div class=\"$name\"".placeAttributes($node).">\n";
            foreach my $n($node->nodes()){
                if($n->{'_'} ne '#'){
                    my $b = build($n,$tabs+1);
                    $bf .= "$b\n" if $b;
                }
            }
        $bf .= $node->val()."\n" if $node->{'#'};   
        $bf .= "\t"x$tabs."</div>"
    }elsif( $name eq 'img' ){
        $bf .= "\t\t<img".placeAttributes($node)."/>\n";
    }elsif($name eq 'list_images'){
        my $paths = $node->{'@@'};
        foreach my $ndp (@$paths){            
            my $path = $ndp -> val();
            my @ext = split(',',"jpg,jpeg,png,gif");
            my $exp = " ".$path."/*.". join (" ".$path."/*.", @ext);
            my @images = glob($exp);
            $bf .= "\t<div class='row'><div class='cell'><b>Directory: $path</b></div></div>";
            foreach my $file(@images){
                ($file=~/.*\/(.*)$/);
                my $fn = $1;
                my $enc = "img@".ShortLink::obtain($file);
                $bf .= qq(\t<div class='row'><div class='cell'>);
                $bf .= qq(\t<a href="$enc"><img src="$enc" with='120' height='120'><br>$fn</a>\n</div></div>\n);
            }
        }    
    }elsif($node->{'*'}){ #Links are already captured, in future this might be needed as a relink from here for dynamic stuff?
            my $lval = $node->{'*'};
            if($name eq 'file_list_html'){ #Special case where html links are provided.                
                foreach(split(/\n/,$lval)){
                     $bf .= qq( [ $_ ] |) if $_
                }
                $bf =~ s/\|$//g;
            }else{ #Generic included link value.
                $bf .= $lval;
            }
    }
    else{
        $bf .= "\t"x$tabs."<".$node->name().placeAttributes($node).">";
            foreach my $n($node->nodes()){                 
                    my $b = build($n,$tabs+1);
                    $bf .= "$b\n" if $b;        
            }
        $bf .= $node->val() if $node->{'#'};
        $bf .= "</".$node->name().">";

    }
    return $bf;
}
#


sub placeAttributes {
    my $node = shift;
    my $ret  = "";
    my @attr = $node -> attributes();
    foreach (@attr){
        if(@$_[0] ne '#' && @$_[0] ne '_'){
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