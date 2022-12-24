package CNFNode;
use strict;
use warnings;


sub new {
    my ($class,$attrs, $self) = @_;
    $self = \%$attrs;
    bless $self, $class;
}
sub name {
    my $self = shift;
    return $self->{'name'}
}
###
# Convienience method, returns string scalar value dereferenced (a copy) of the property value.
##
sub val {
    my $self = shift;
    my $ret = $self->{'#'};
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
        if($_ ne '@' && $_ ne '@$' && $_ ne '#' && $_ ne '_'){
            $nodes[@nodes] = [$_, $node]
        }
    }
    return @nodes;
}
###
# Search a path for node from a path statement.
# It will always return an array for even a single suproperty. 
# The reason is several subproperties of the same name can be contained by the parent property.
# It will return an array of list values with (@@).
# Or will return an array of its shallow list of child nodes with (@$). 
# Or will return an scalar value of an attribute or an subproperty with (#).
# NOTICE - 20221222 Future versions might provide also for more complex path statments with regular experssions enabled.
###
sub find {
    my ($self, $path, $ret, $prev)=@_;
    my @arr;
    foreach my $name(split(/\//, $path)){  
        if(ref($self) eq "ARRAY"){      
            
            if($name eq '#'){
                return $prev->val();
            }else{
                #if(@$self == 1){
                    $ret = $prev->{'@$'};
               # }
            }
        }else{             
            if ($name eq '@@') {
                $ret =  $self->{'@@'};
                next
            }else{ 
                $ret = $self->{'@$'} #This will initiate further search in subproperties names.
            }
        }
        if($ret){
            my $found = 0;            
            foreach(@$ret){
                if (ref($_) eq "CNFNode" and $_->{'name'} eq $name){
                    if($prev){                       
                       if(ref($prev) eq "ARRAY"){
                        @arr = @$prev;
                       }else{ 
                         @arr = ();
                         $arr[@arr] = $self;  
                       }
                       $arr[@arr] = $_;
                       $self = \@arr;
                       $prev = $_;  
                       
                    }else{ 
                       $prev = $self = $_
                    }               
                    $found = 1;
                    $ret = $_  
                }
                # else{ 
                #     #$self = $prev if $prev && $prev ne 1;
                #     $self = $prev if $prev
                # }
            }
            $ret = $self->{$name} if(!$found && $name ne '@$');
        }else{ 
            $ret = $self->{$name} ;
        }   
    }
    return $ret;
}
sub node {
    my ($self, $path, $ret)=@_;
    foreach my $name(split(/\//, $path)){        
        $ret = $self->{'@$'};
        if($ret){
            foreach(@$ret){
                if ($_->{'name'} eq $name){
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
# The parsing guts of the CNFNode, that from raw script, recursively creates and tree of nodes from it.
###
sub process {

    my ($self, $parser, $script)=@_;      
    my ($sub, $val, $isArray,$body) = (undef,0,0,"");
    my ($tag,$sta,$end);    
    my @array = ();
    my ($opening,$closing)=(0,0);

    if($self->{'name'} eq '#'){
       $val = $self->{'#'};
       if($val){
          $val .= "\n$script";
       }else{ 
          $val = $script;
       }
    }else{
        my @lines = split(/\n+\s*/, $script);
        foreach my $ln(@lines){
            $ln =~ s/^\s+|\s+$//g;
            my $len =  length ($ln);
            if($len>0){
                #print $ln, "\n";
                if($ln =~ /^([<>\[\]])(.*)([<>\[\]])$/){
                    $sta = $1;
                    $tag = $2;
                    $end = $3;
                    my $isClosing = ($sta =~ /[>\]]/) ? 1 : 0;
                    if($tag =~ /^([#\*\@]+)[\[<](.*)[\]>]\/*[#\*\@]+$/){#<- The \/ can sneak in as included in closing tag.
                        if($1 eq '*'){
                            my $link = $2;
                            my $lval = $parser->anon($2);
                            $lval    = $parser->{$2} if !$lval; #Anon is passed as an unknown constance (immutable).
                            if($lval){                                
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
                                        $nodes[@nodes] = CNFNode->new({name=>"$link", '*'=>$lval});
                                        $self->{'@$'} = \@nodes;
                                    }
                                    else{
                                        #Links scripted in main tree parent are copied main tree attributes.
                                        $self->{$link} = $lval
                                    }                                 
                                }
                                next
                            }else{ 
                                if(!$opening){warn "Anon link $link not located with $ln for node ".$self->{'name'}};
                            }
                         }elsif($1 eq '@@'){
                                if($opening==$closing){
                                   $array[@array] = $2; $val="";     
                                   next                              
                                }
                         }else{ 
                            $val = $2
                         }                         
                    }
                    elsif($tag =~ /^(.*)[\[<](.*)[\]>](.*)$/ && $1 eq $3){
                        if($opening){
                                $body .= qq($ln\n)
                        }
                        else{
                                my $subProperty = CNFNode->new({name=>"$1"});
                                $subProperty ->{'#'} = $2;
                                $subProperty->{'@'} = \$self; 
                                my @nodes;
                                my $prev = $self->{'@$'};
                                if($prev) {
                                    @nodes = @$prev;
                                }else{
                                    @nodes = ();                                   
                                }                        
                                $nodes[@nodes] = $subProperty;
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
                        
                        if($tag =~ /@@/){
                    
                            $isArray = $isArray?0:1;
                            $body="";
                            next

                        }
                        $sub = $tag;  $body="";
                        next

                    }elsif($tag eq $sub){
                        if($closing == 0){
                            if($tag eq '#'){
                                if(!$val){
                                    $self->{'#'} = \$body
                                }
                            }else{                        
                                my $subProperty = CNFNode->new({name=>"$sub"});
                                $subProperty->{'@'} = \$self; 
                                my @nodes;
                                my $prev = $self->{'@$'};
                                if($prev) {
                                   @nodes = @$prev;
                                }else{
                                   @nodes = ();                                   
                                }
                                $nodes[@nodes] = $subProperty->process($parser, $body);
                                $self->{'@$'} = \@nodes;
                                undef $sub; $body = $val = "";
                            }
                            next   
                        }             
                    }
                    $body .= qq($ln\n)
                }elsif($sub){
                    $body .= qq($ln\n)
                }
                elsif($val){
                    $val = $self->{'#'};
                    if($val){
                        $self->{'#'} = qq($val\n$ln\n);
                    }else{ 
                        $self->{'#'} = qq($ln\n);
                    }
                }elsif($isArray){
                    $array[@array] = $ln;
                }        
                else{ 
                    my @attr = ($ln =~m/([\s\w]*?)\s*[=:]\s*(.*)\s*/);
                    if(@attr>1){
                        my $n = $attr[0];
                        my $v = $attr[1];                         
                        $self->{$n} = $v;
                    }
                }
            }
        }
    }
                        
    $self->{'@@'} = \@array if @array;
    $self->{'#'} = $val if $val;
    $self->{'_'} = 1;
    return $self;
}

1;