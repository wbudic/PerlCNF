# SQL Processing part for the Configuration Network File Format.
# Programed by  : Will Budic
# Source Origin : https://github.com/wbudic/PerlCNF.git
# Open Source License -> https://choosealicense.com/licenses/isc/
#
package CNFtoJSON;

use strict;use warnings;#use warnings::unused;
use Exception::Class ('CNFParserException'); use Carp qw(cluck);
use Syntax::Keyword::Try;
use Time::HiRes qw(time);
use DateTime;

use constant VERSION => '1.0';

sub new {
    my ($class, $attrs,$self) = @_;
    $self = {};
    $self = \%$attrs if $attrs;
    bless $self, $class;
}
###
sub nodeToJSON {
    my($self,$node,$tab_cnt)=@_; $tab_cnt=1 if !$tab_cnt;
    if($self&&$node){
       my ($buffer,$attributes,$closeBrk)=("","",0);
       my $tab =  $tab_cnt == 1 ? '' : '   ' x $tab_cnt;
       my $name = $node -> {'_'};
       my $val  = $node -> {'#'}; $val = $node->{'*'} if !$val; $val = _translateNL($val);
       my @arr  = sort (keys %$node);       
          foreach (@arr){
            my $attr = $_;            
            if($attr !~ /@\$|[@+#_~]/){
               my $aval = _translateNL($node->{$attr});               
                  $attributes .= ",\n" if $attributes;
                  $attributes .= "$tab\"$attr\" : \"$aval\"";
            }            
          }          
       #
            @arr  = exists $node-> {'@$'} ?  @{$node -> {'@$'}} : ();
       #       
       return \"$tab\"$name\" : \"$val\"" if(!@arr==0 && $val);       
       $tab_cnt++;
       if(@arr){
          foreach (@arr){
            if (!$buffer){          
                $attributes.= ",\n" if $attributes;
                $buffer     = "$attributes$tab\"$name\" : {\n";
                $attributes = ""; $closeBrk = 1;
            }else{ 
                $buffer .= ",\n"
            }
            my $sub = $_->name();
            my $insert = nodeToJSON($self, $_, $tab_cnt);
            if(length($$insert)>0){
               $buffer .= $$insert;
            }else{
               $buffer .= $tab.('   ' x $tab_cnt)."\"$sub\" : {}"
            }
          }          
       }
       if($attributes){
          $buffer     .= $node->isRoot() ? "$tab$attributes" :  "$tab\"$name\" : {\n$tab$attributes";
          $attributes  = "";  $closeBrk=2;
       }
       #
            @arr  = exists $node-> {'@@'}  ?  @{$node -> {'@@'}} : ();
       #
       if(@arr){          
          foreach (@arr){
            if (!$attributes){
                 $attributes  = "$tab\"$name\" : [\n"
            }else{ 
             $buffer .= ",\n"
            }
            $buffer .= "\"$_\"\n"            
          }
           $buffer .= $attributes."\n$tab]"
       }
       if ($closeBrk){
           $buffer .= "\n$tab}"
       }
       if($node->isRoot()){
           $buffer =~ s/\n/\n  /gs;
           $buffer = $tab."{\n  ".$buffer."\n"."$tab}";
       }
       return \$buffer

    }else{
        die "Where is the node, my friend?"
    }
}
sub _translateNL {
    my $val = shift;
    if($val){
       $val =~ s/\n/\\n/g;
    }
    return $val
}


1;