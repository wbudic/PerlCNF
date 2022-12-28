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
#

###
# Search a path for node from a path statement.
# It will always return an array for even a single suproperty. 
# The reason is several subproperties of the same name can be contained by the parent property.
# It will return an array of list values with (@@).
# Or will return an array of its shallow list of child nodes with (@$). 
# Or will return an scalar value of an attribute or an property with (#).
# NOTICE - 20221222 Future versions might provide also for more complex path statments with regular experssions enabled.
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
                #if(@$self == 1){
                    $ret = $prev->{'@$'};
               # }
            }
        }else{             
            if($name eq '@@') {
                $ret = $self->{'@@'}; $seekArray = 1;
                next
            }elsif($name eq '@$') {
                $ret = $self->{'@$'}; #This will initiate further search in subproperties names.
                next
            }elsif($name eq '#'){
                return $ret->val()
            }if(ref($ret) eq "CNFNode" && $seekArray){
                $ret = $ret->{$name};
                next
            }else{ 
                $ret = $self->{'@$'} if ! $seekArray; #This will initiate further search in subproperties names.                
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
                        if ($n->{'name'} eq $name){
                            $arr[@arr] = $n;
                        }                        
                    }
                    if(@arr>1){
                       $ret = \@arr;
                    }else{ 
                       $ret = $n;
                    }
                    $found++;
                }elsif (ref($_) eq "CNFNode" and $_->{'name'} eq $name){
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
                       $ret = \@arr;
                    }
                    $found=1
                }
            }
            $ret = $self->{$name} if(!$found && $name ne '@$');
        }else{ 
            $ret = $self->{$name} ;
        }   
    }
    return $ret;
}
#
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
    my ($tag,$sta,$end)=("","","");    
    my @array;
    my ($opening,$closing,$valing)=(0,0,0);

    if($self->{'name'} eq '#'){
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
            #print $ln, "<-","\n";            
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
                                        $nodes[@nodes] = CNFNode->new({name=>"$link", '*'=>$lval,'@' => \$self});
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
                            $val = $2;                            
                         }                         
                    }
                    elsif($tag =~ /^(.*)[\[<]\/*(.*)[\]>](.*)$/ && $1 eq $3){
                        if($opening){
                                $body .= qq($ln\n)
                        }
                        else{
                                my $property = CNFNode->new({name=>$1, '#' => $2, '@' => \$self});
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
                        
                        if($tag =~ /@@/){
                    
                            $isArray = $isArray?0:1;
                            # $body="";
                            # next

                        }
                        $sub = $tag;  $body="";
                        next

                    }elsif($tag eq $sub && $isClosing){
                        if($opening==$closing){
                            if($tag eq '#'){
                                $body =~ s/\s$//;#cut only one last nl if any.
                                if(!$val){                                    
                                    $val = $body;
                                }else{ 
                                    $val .= $body
                                }
                                $valing = 0;
                            }else{         
                                my $a = $isArray;
                                my $property = CNFNode->new({name=>"$sub", '@' => \$self});                                   
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
                                my $lval = $parser->anon($4);
                                $lval    = $parser->{$4} if !$lval; #Anon is passed as an unknown constance (immutable).
                                if($lval){
                                        #Is this a child node?
                                        if(exists $self->{'@'}){
                                            my @nodes;
                                            my $prev = $self->{'@$'};
                                            if($prev) {
                                               @nodes = @$prev;
                                            }else{
                                               @nodes = ();                                   
                                            }
                                            $nodes[@nodes] = CNFNode->new({name=>"$link", '*'=>$lval, '@' => \$self});
                                            $self->{'@$'} = \@nodes;
                                        }
                                        else{
                                            #Links scripted in main tree parent are copied main tree attributes.
                                            $self->{$link} = $lval
                                        }                                 
                                    
                                }else{ 
                                    warn "Anon link $link not located with $ln for node ".$self->{'name'} if !$opening;
                                }
                        }elsif($2 eq '@@'){
                               $array[@array] = CNFNode->new({name=>"$2",'#'=>$4, '@' => \$self});                               
                        }else{
                                my $property = CNFNode->new({name=>"$2",'#'=>$4,'@' => \$self});                                
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
                 $body .= qq($ln\n)
            }
            elsif($tag eq '#'){
                 $body .= qq(\n)
            }
        }        
    }

    $self->{'@@'} = \@array if @array;
    $self->{'#'} = \$val if $val;
    return $self;
}

1;