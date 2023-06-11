# 
# Represents a tree node CNF object having children and a parent node if it is not the root.
# Programed by  : Will Budic
# Notice - This source file is copied and usually placed in a local directory, outside of its project.
# So it could not be the actual or current version, can vary or has been modiefied for what ever purpose in another project.
# Please leave source of origin in this file for future references.
# Source of Origin : https://github.com/wbudic/PerlCNF.git
# Documentation : Specifications_For_CNF_ReadMe.md
# Open Source Code License -> https://choosealicense.com/licenses/isc/
#
package CNFNode;
use strict;
use warnings;
use Carp qw(cluck);

require CNFMeta; CNFMeta::import();

sub new {
    my ($class, $attrs) = @_;
    my $self = \%$attrs;
    bless $self, $class;
}
sub name {
    my $self = shift;
    return $self->{'_'}
}

sub _run {
    my $value = shift;
    my $meta =  meta(SHELL());    
    if($value =~ s/($meta)//i){
       $value =~ s/^`|`\s*$/""/g; #we strip as a possible monkey copy had now redundant meta in the value.
       $value = '`'.$value.'`';
    }
    ## no critic BuiltinFunctions::ProhibitStringyEval                        
    my $ret = eval $value;
    ## use critic            
    if ($ret){
        chomp  $ret;
        return $ret;
    }else{
        cluck("Perl DO_ENABLED script evaluation failed to evalute: $value Error: $@");
        return '<<ERROR>>';
    }
}
###
# Convenience method, returns string scalar value dereferenced (a copy) of the property value.
##
sub val {
    my $self = shift;
    my $ret = $self->{'#'};          # Standard value
       $ret = $self->{'*'} if !$ret; # Linked value
       $ret = _run($self->{'&'}) if !$ret and exists $self->{'&'}; # Evaluated value
    if(!$ret && $self->{'@$'}){ #return from subproperties.
        my $buf;
        my @arr = @{$self->{'@$'}};
        foreach my $nv(@arr){
            $nv = $nv->val();
            $buf .= qq($nv\n);
        }
        return $buf;
    }
    if(ref($ret) eq 'SCALAR'){
           $ret = $$ret;
     }
    return $ret
}
sub parent {
    my $self = shift;
    return $self->{'@'}
}

sub attributes {
    my $self = shift;
    my @nodes;
    foreach(sort keys %$self){
        my $node = $self->{$_};        
        if($_ !~ /@|@\$|#_/){
           $nodes[@nodes] = [$_, $node]
        }
    }
    return @nodes;
}
#

###
# Search select nodes based on from a path statement.
# It will always return an array for even a single subproperty. 
# The reason is several subproperties of the same name can be contained by the parent property.
# It will return an array of list values with (@@).
# Or will return an array of its shallow list of child nodes with (@$). 
# Or will return an scalar value of an attribute or an property with (#).
# NOTICE - 20221222 Future versions might provide also for more complex path statements with regular expressions enabled.
###
sub find {
    my ($self, $path, $ret, $prev, $seekArray)=@_;
    foreach my $name(split(/\//, $path)){  
        if(ref($self) eq "ARRAY"){            
            if($name eq '#'){
                if(ref($ret) eq "ARRAY"){                    
                    next
                }else{
                    return $prev->val()
                }
            }elsif($name =~ /\[(\d+)\]/){
                   $self = $ret = @$ret[$1];
                   next

            }else{
                   $ret = $prev->{'@$'};               
            }
        }else{             
            if($name eq '@@') {
                $ret = $self->{'@@'}; $seekArray = 1;
                next
            }elsif($name eq '@$') {
                $ret = $self->{'@$'}; # This will initiate further search in subproperties names.
                next
            }elsif($name eq '#'){
                return $ret->val()
            }if(ref($ret) eq "CNFNode" && $seekArray){
                $ret = $ret->{$name};
                next
            }else{ 
                $ret = $self->{'@$'} if ! $seekArray; # This will initiate further search in subproperties names.                
            }
        }
        if($ret){
            my $found = 0;
            my @arr;
            undef $prev;        
            foreach(@$ret){
                if($seekArray && exists $_->{'@$'}){
                    my $n;
                    foreach (@{$_->{'@$'}}){
                        $n = $_;
                        if ($n->{'_'} eq $name){
                            $arr[@arr] = $n;
                        }                        
                    }
                    if(@arr>1){
                       $ret = \@arr;
                    }else{ 
                       $ret = $n;
                    }
                    $found++;
                }elsif (ref($_) eq "CNFNode" and $_->{'_'} eq $name){
                    if($prev){
                       $arr[@arr] = $_;
                       $self = \@arr;
                       $prev = $_;
                    }else{ 
                       $arr[@arr] = $_;
                       $prev = $self = $_
                    }
                    if(!$found){
                       $self = $ret = $_
                    }else{ 
                       $ret  = \@arr;
                    }
                    $found=1
                }
            }
            $ret = $self->{$name} if(!$found && $name ne '@$');
        }else{ 
            if(ref($ret) ne "ARRAY"){
                   $ret = $self->{$name} 
            }
        }   
    }
    return $ret;
}
###
# Similar to find, put simpler node by path routine.
# Returns first node found based on path..
###
sub node {
    my ($self, $path, $ret)=@_;
    foreach my $name(split(/\//, $path)){        
        $ret = $self->{'@$'};
        if($ret){
            foreach(@$ret){
                if ($_->{'_'} eq $name){
                    $ret = $_; last
                }
            }
        }
    }
    return $ret;    
}

sub nodes {
    my $self = shift;
    my $ret = $self->{'@$'};
    if($ret){
        return @$ret;
    }
    return ();
}

###
# Outreached subs list of collected node links found in a property.
my  @linked_subs;

###
# The parsing guts of the CNFNode, that from raw script, recursively creates and tree of nodes from it.
###
sub process {

    my ($self, $parser, $script)=@_;      
    my ($sub, $val, $isArray,$body) = (undef,0,0,"");
    my ($tag,$sta,$end)=("","","");    
    my @array;
    my ($opening,$closing,$valing)=(0,0,0);

    if(exists $self->{'_'} && $self->{'_'} eq '#'){
       $val = $self->{'#'};
       if($val){
          $val .= "\n$script";
       }else{ 
          $val = $script;
       }
    }else{
        my @lines = split(/\n/, $script);
        foreach my $ln(@lines){
            $ln =~ s/^\s+|\s+$//g;          
            if(length ($ln)){
                #print $ln, "\n";
                if($ln =~ /^([<>\[\]])(.*)([<>\[\]])$/ && $1 eq $3){
                   $sta = $1;
                   $tag = $2;
                   $end = $3;
                   my $isClosing = ($sta =~ /[>\]]/) ? 1 : 0;
                    if($tag =~ /^([#\*\@]+)[\[<](.*)[\]>]\/*[#\*\@]+$/){#<- The \/ can sneak in as included in closing tag.
                        if($1 eq '*'){
                            my $link = $2;
                            my $rval = $self -> obtainLink($parser, $link);                                                             
                               $rval = $parser->{$link} if !$rval; #Anon is passed as an unknown constance (immutable).
                            if($rval){                 
                                if($opening){
                                   $body .= qq($ln\n);                                   
                                }else{
                                    #Is this a child node?
                                    if(exists $self->{'@'}){
                                        my @nodes;
                                        my $prev = $self->{'@$'};
                                        if($prev) {
                                            @nodes = @$prev;
                                        }else{
                                            @nodes = ();                                   
                                        }
                                        $nodes[@nodes] = CNFNode->new({'_'=>$link, '*'=>$rval,'@' => \$self});
                                        $self->{'@$'} = \@nodes;
                                    }
                                    else{
                                        #Links scripted in main tree parent are copied main tree attributes.
                                        $self->{$link} = $rval
                                    }                                 
                                }
                                next
                            }else{ 
                                if(!$opening){warn "Anon link $link not located with $ln for node ".$self->{'_'}};
                            }
                         }elsif($1 eq '@@'){
                                if($opening==$closing){
                                   $array[@array] = $2; $val="";     
                                   next                              
                                }
                         }else{ 
                            $val = $2;                            
                         }                         
                    }
                    elsif($tag =~ /^(.*)[\[<]\/*(.*)[\]>](.*)$/ && $1 eq $3){
                        if($opening){
                                $body .= qq($ln\n)
                        }
                        else{
                                my $property = CNFNode->new({'_'=>$1, '#' => $2, '@' => \$self});
                                my @nodes;
                                my $prev = $self->{'@$'};
                                if($prev) {
                                    @nodes = @$prev;
                                }else{
                                    @nodes = ();                                   
                                }                        
                                $nodes[@nodes] = $property;
                                $self->{'@$'} = \@nodes;
                        }
                        next
                    }
                    elsif($isClosing){
                        $opening--;
                        $closing++;                        
                    }
                    else{
                        $opening++;
                        $closing--;                        
                    }

                    if(!$sub){                
                        $isArray = $isArray? 0 : 1 if $tag =~ /@@/;
                        $sub = $tag;  $body = "";
                        next
                    }elsif($tag eq $sub && $isClosing){
                        if($opening==$closing){
                            if($tag eq '#'){
                                $body =~ s/\s$//;#cut only one last nl if any.
                                if(!$val){                                    
                                    $val  = $body;
                                }else{ 
                                    $val .= $body
                                }
                                $valing = 0;
                                $tag ="" if $isClosing
                            }else{         
                                my $a = $isArray;
                                my $property = CNFNode->new({'_'=>$sub, '@' => \$self});                                   
                                $property->process($parser, $body);
                                $isArray = $a;
                                if($tag eq '@@'){
                                   $array[@array] = $property;
                                   if( not exists $property->{'#'} && $body ){ 
                                       $body =~ s/\n$//; $property->{'#'} = $body
                                   }
                                }else{
                                    my @nodes;
                                    my $prev = $self->{'@$'};
                                    if($prev) {
                                       @nodes = @$prev;
                                    }else{
                                       @nodes = ();                                   
                                    }
                                    $nodes[@nodes] = $property;
                                    $self->{'@$'} = \@nodes;
                                }
                                undef $sub; $body = $val = "";
                            }
                            next   
                        }else{
                           # warn "Tag $sta$tag$sta failed closing -> $body"
                        }             
                    }               
                }elsif($tag eq '#'){
                       $valing = 1;
                }elsif($opening==0 && $isArray){
                    $array[@array] = $ln;  
                   # next              
                }elsif($opening==0 && $ln =~ /^([<\[])(.+)([<\[])(.*)([>\]])(.+)([>\]])$/ && 
                              $1 eq $3 && $5 eq $7 ){ #<- tagged in line
                        if($2 eq '#') {
                            if($val){$val = "$val $4"}
                            else{$val = $4}                           
                        }elsif($2 eq '*'){
                                my $link = $4;
                                my $rval = $self->obtainLink($parser, $link);                                                             
                                   $rval = $parser->{$link} if !$rval; #Anon is passed as an unknown constance (immutable).
                                if($rval){
                                        #Is this a child node?
                                        if(exists $self->{'@'}){
                                            my @nodes;
                                            my $prev = $self->{'@$'};
                                            if($prev) {
                                               @nodes = @$prev;
                                            }else{
                                               @nodes = ();                                   
                                            }
                                            $nodes[@nodes] = CNFNode->new({'_'=>$link, '*'=>$rval, '@' => \$self});
                                            $self->{'@$'} = \@nodes;
                                        }
                                        else{
                                            #Links scripted in main tree parent are copied main tree attributes.
                                            $self->{$link} = $rval
                                        }                                 
                                    
                                }else{ 
                                    warn "Anon link $link not located with '$ln' for node ".$self->{'_'} if !$opening;
                                }
                        }elsif($2 eq '@@'){
                               $array[@array] = CNFNode->new({'_'=>$2, '#'=>$4, '@' => \$self});                               
                        }else{
                                my $property  = CNFNode->new({'_'=>$2, '#'=>$4, '@' => \$self});                                
                                my @nodes;
                                my $prev = $self->{'@$'};
                                if($prev) {
                                    @nodes = @$prev;
                                }else{
                                    @nodes = ();                                   
                                }
                                $nodes[@nodes] = $property;
                                $self->{'@$'} = \@nodes;
                        }

                    next                               
                }elsif($val){
                    $val = $self->{'#'};
                    if($val){
                        $self->{'#'} = qq($val\n$ln\n);
                    }else{ 
                        $self->{'#'} = qq($ln\n);
                    }
                }
                elsif($opening < 1){
                    if($ln =~m/^([<\[]@@[<\[])(.*?)([>\]@@[>\]])$/){
                       $array[@array] = $2;
                       next;
                    }
                    my @attr = ($ln =~m/([\s\w]*?)\s*[=:]\s*(.*)\s*/);
                    if(@attr>1){
                        my $n = $attr[0];
                        my $v = $attr[1];                         
                        $self->{$n} = $v;
                        next;
                    }else{ 
                       $val = $ln if $val;
                    }                   
                }
                                    # Very complex rule, allow #comment lines in buffer withing an node value tag, ie [#[..]#]
                 $body .= qq($ln\n) #if !$tag &&  $ln!~/^\#/ || $tag eq '#' 
            }
            elsif($tag eq '#'){
                 $body .= qq(\n)
            }
        }        
    }

    $self->{'@@'} = \@array if @array;
    $self->{'#'} = \$val if $val;
    ## no critic BuiltinFunctions::ProhibitStringyEval
    no strict 'refs';       
    while(@linked_subs){
       my $entry = pop (@linked_subs);  
       my $node  = $entry->{node};
       my $res   = &{+$entry->{sub}}($node);
       $entry->{node}->{'*'} = \$res;
    }
    return \$self;
}

sub obtainLink {
    my ($self,$parser,$link, $ret) = @_;
    ## no critic BuiltinFunctions::ProhibitStringyEval
    no strict 'refs';
    if($link =~/(.*)(\(\.\))$/){       
       push @linked_subs, {node=>$self,link=>$link,sub=>$1};
       return 1;
    }elsif($link =~/(\w*)::\w+$/){
        use Module::Loaded qw(is_loaded);
        if(is_loaded($1)){
           $ret = \&{+$link}($self);                                        
        }else{
            cluck qq(Package  constance link -> $link is not available (try to place in main:: package with -> 'use $1;')")
        }
    }else{
        $ret = $parser->anon($link);
    }    
    return $ret;
}

###
# Validates a script if it has correctly structured nodes.
#
sub validate {
    my ($self, $script) = @_;
    my ($tag,$sta,$end,$lnc,$errors)=("","","",0,0); 
    my (@opening,@closing,@singels);
    my ($open,$close) = (0,0);
    my @lines = split(/\n/, $script);    
    foreach my $ln(@lines){
        $ln =~ s/^\s+|\s+$//g;
        $lnc++;
        #print $ln, "<-","\n";            
        if(length ($ln)){
            #print $ln, "\n";
            if($ln =~ /^([<>\[\]])(.*)([<>\[\]])$/ && $1 eq $3){
                $sta = $1;
                $tag = $2;
                $end = $3;
                my $isClosing = ($sta =~ /[>\]]/) ? 1 : 0;
                if($tag =~ /^([#\*\@]+)[\[<](.*)[\]>]\/*[#\*\@]+$/){

                }elsif($tag =~ /^(.*)[\[<]\/*(.*)[\]>](.*)$/ && $1 eq $3){
                    $singels[@singels] = $tag;
                    next
                }
                elsif($isClosing){
                      $close++;
                      push @closing, {T=>$tag, idx=>$close, L=>$lnc, N=>($open-$close+1),S=>$sta};
                }
                else{                      
                      push @opening, {T=>$tag, idx=>$open, L=>$lnc, N=>($open-$close),S=>$sta};
                      $open++;
                 }
            }
        }
    }
    if(@opening != @closing){ 
       cluck "Opening and clossing tags mismatch!";
       foreach my $o(@opening){          
          my $c = pop @closing;
          if(!$c){
            $errors++;
             warn "Error unclosed tag-> [".$o->{T}.'[ @'.$o->{L}       
          }
       }
       
    }else{
       my $errors = 0; my $error_tag; my $nesting;
       my $cnt = $#opening;
       for my $i (0..$cnt){
          
          my $o = $opening[$i];          
          my $c = $closing[$cnt - $i];
          if($o->{T} ne $c->{T}){
            print '['.$o->{T}."[ idx ".$o->{idx}." line ".$o->{L}.
                  ' but picked for closing: ]'.$c->{T}.'] idx '.$o->{idx}.' line '.$c->{L}."\n" if $self->{DEBUG};
            # Let's try same index from the clossing array.
            $c = $closing[$i];
          }else{next}

          if($o->{T} ne $c->{T}){
                my $j = $cnt;
                for ($j = $cnt; $j>-1; $j--){  # TODO 2023-0117 - For now matching by tag name, 
                     $c = $closing[$j];# can't be bothered, to check if this will always be appropriate.
                    last if $c -> {T} eq $o->{T}
                }
                print "\t search [".$o->{T}.'[ idx '.$o->{idx} .' line '.$o->{L}. 
                      ' top found: ]'.$c->{T}."] idx ".$c->{idx}." line ".$c->{N}." loops: $j \n" if $self->{DEBUG};
          }else{next}

          if($o->{T} ne $c->{T} && $o->{N} ne $c->{N}){
             cluck "Error opening and clossing tags mismatch for ". 
                    brk($o).' ln: '.$o->{L}.' idx: '.$o->{idx}.
                    ' wrongly matched with '.brk($c).' ln: '.$c->{L}.' idx: '.$c->{idx}."\n";
             $errors++;
          }
       }       
    }
    return  $errors;
}

sub brk{
    my $t = shift;
    return 'tag: \''.$t->{S}.$t->{T}.$t->{S}.'\''
}

1;