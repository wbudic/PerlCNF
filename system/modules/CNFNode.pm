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
    my ($sub, $val, $body) = (undef,0,"");
    my @lines = split(/\n+\s*/, $script);
    foreach my $ln(@lines){
        $ln =~ s/\s+//g;
        my $len =  length ($ln);
        if($len>0){
        #print $ln, "\n";
        if(substr($ln, 0, 1) eq '[' && substr($ln, $len-1, 1) eq ']'){
            my $tag = substr($ln, 1, $len-2);
            if($tag =~ /^#\](.*)\[\/#$/ ){
                $val = $1;
            }
            elsif($tag =~ /\/*#/){
                if(!$val){$val=1}else{$self->{'#'} = $val; undef $val};
                next
            }
            elsif(!$sub){
                $sub = substr($ln, 1, $len-2);
                next
            }elsif(substr($ln, 1, 1) eq '/'){
                my $tag = substr($ln, 2, $len-3);
                if($tag eq $sub){
                    my $subProperty = CNFNode->new({name=>"$sub"});
                    $subProperty->{'@'} = \$self;                    
                    $self->{$sub} = $subProperty->process($body);
                    undef $sub; $body = $val = "";
                    next
                }
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
        }else{ 
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
    $self->{'#'} = $val if $val;
    return $self;
}
1;