package CNFNode;
use strict;
use warnings;

sub new {
    my ($class,$attrs,$self) = @_;
    $self = \%$attrs;
    bless $self, $class;
}
sub name {
    my $self = shift;
    return $self->{'name'}
}
sub val {
    my $self = shift;
    return $self->{'#'}
}
sub parent {
    my $self = shift;
    return $self->{'@'}
}
sub find {
    my ($self, $path, $ret)=@_;
    my $node = $self;
    foreach my $name(split(/\//, $path)){        
        $ret = $node->{$name};
        if($ret){
        # print ref($ret) ,"\n";
        if(ref($ret) eq 'CNFNode'){
            $node = $ret;
        }         
        }      
    }
    return \$ret;
}


sub process {

    my ($self, $script)=@_;      
    my ($sub, $val, $isArray,$body) = (undef,0,0,"");
    my ($tag,$sta,$closing,$end);
    my @array = ();
    my @lines = split(/\n+\s*/, $script);
    foreach my $ln(@lines){
        $ln =~ s/^\s+|\s+$//g;
        my $len =  length ($ln);
        if($len>0){
            #print $ln, "\n";
            if($ln =~ /^([<>\[\]])(.*)([<>\[\]])$/){
                $sta = $1;
                $tag = $2;#substr($ln, 1, $len-2);
                $end = $3;
                $closing = ($sta =~ /[\>\]]/) ? 1 : 0;

                if(!$body && $tag =~ /^#[<\[](.*)[>\]]#$/ ){
                   $val = $1;                                      
                }
                elsif($sta ne $end){
                   $body .= qq($ln\n); next 
                }     
                elsif(!$sub){                
                    
                    if($tag =~ /@@/){
                 
                        $isArray = $isArray?0:1;
                        $body="";
                        next

                    }
                    $sub = $tag;  $body="";
                    next

                }elsif($closing&& $tag eq $sub){
                    my $subProperty = CNFNode->new({name=>"$sub"});
                    $subProperty->{'@'} = \$self;                    
                    $self->{$sub} = $subProperty->process($body);
                    undef $sub; $body = $val = "";
                    next                
                }
                $body .= qq($ln\n)
            }elsif($sub){
                $body .= qq($ln\n)
            }elsif($val){
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
                my @attr = ($ln =~m/(.*)[:=]+(.*)/);
                if(@attr>1){
                    my $n = $attr[0];
                    my $v = $attr[1]; 
                    $v =~  s/^\s+|\s+$//;
                    $self->{$n} = $v;
                }
            }
        }
    }

                        
    $self->{'@Array'} = \@array if @array;
    $self->{'#'} = $val if $val;
    return $self;
}

1;