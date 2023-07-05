# SQL Processing part for the Configuration Network File Format.
# Programed by  : Will Budic
# Source Origin : https://github.com/wbudic/PerlCNF.git
# Open Source License -> https://choosealicense.com/licenses/isc/
#
package CNFJSON;

use strict;use warnings;#use warnings::unused;
use Exception::Class ('CNFParserException'); use Carp qw(cluck);
use Syntax::Keyword::Try;
use JSON::ize;

use constant VERSION => '1.0';

sub new {
    my ($class, $attrs,$self) = @_;
    $self = {};
    $self = \%$attrs if $attrs;
    bless $self, $class;
}
###
sub nodeToJSON {
    my($self,$node,$tab_cnt) = @_; $tab_cnt=1 if !$tab_cnt;
    if($self&&$node){
       my ($buffer,$attributes,$closeBrk)=("","",0);
       my $tab =  $tab_cnt == 1 ? '' : '   ' x $tab_cnt;
       my $name = $node -> {'_'};
       my $val  = $node -> {'#'}; $val = $node->{'*'} if !$val; $val = _translateNL($val);
       my @arr  = sort (keys %$node);  
       my $regex  = $node->PRIVATE_FIELDS();
          foreach my$attr(@arr){            
            if($attr !~ /$regex/){
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
          $closeBrk=2 if (!$buffer && !$node->isRoot());
          $buffer     .= $node->isRoot() ? "$tab$attributes" :  "$tab\"$name\" : {\n$tab$attributes";
          $attributes  = "";  
       }
       #
            @arr  = exists $node-> {'@@'}  ?  @{$node -> {'@@'}} : ();
       #
       if(@arr){          
          foreach (@arr){
            if (!$attributes){
                 $attributes  = "$tab\"$name\" : [\n"
            }else{ 
                 $attributes .= ",\n"
            }
                 $attributes .= $tab.('   ' x $tab_cnt).'"'.$_->val().'"'            
          }
           $buffer .= $attributes."\n$tab]"
       }
       if ($closeBrk){
           $buffer .= "\n$tab}"
       }
       if ($node->isRoot()){
           $buffer =~ s/\n/\n  /gs;           
           while (my ($k, $v) = each %$self) {  $buffer .= qq(,\n"$k" : "$v") } 
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

sub jsonToCNFNode {
    my($self,$json,$name) = @_;
    if($self&&$json){    
        my $obj  = jsonize($json);
        return   _objToCNF($name, $obj) 
    }
 }
      sub _jsonToObj {
         return jsonize(shift);
      }

 sub _objToCNF {
     my($name, $obj) = @_; $name = 'root' if !$name;
     my $ret  = CNFNode->new({'_'=>$name});
        my %perl = %$obj;
        foreach my $atrr(keys %perl){
                my $val = $perl{$atrr};
                my $ref = ref($val);
                if($ref eq 'HASH'){
                   $val =  _objToCNF($atrr, $val);
                   my @arr = $ret->{'@$'} ? $ret->{'@$'} : ();
                   $arr[@arr]   = $val;
                   $ret->{'@$'} = \@arr;
                }elsif($ref eq 'ARRAY'){
                   $ret->{'@$'} = \@$val
                }else{
                   $ret -> {$atrr} = $val
                }
        }
    return $ret;
 }
 
1;