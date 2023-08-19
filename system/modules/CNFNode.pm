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

use constant PRIVATE_FIELDS => qr/@\$|[@#_~^&]/o;

###
# CNFNode uses symbol offcodes for all its own field values, foe efficiancy.
###
sub name     {shift -> {'_'}}
sub parent   {shift -> {'@'}}
sub isRoot   {not exists shift -> {'@'}}
sub list     {shift -> {'@@'}}
sub script   {shift -> {'~'}}
sub priority {shift -> {'^'}}
sub evaluate {shift -> {'&'}}
sub attributes {
    my $self = shift;
    my @attributes;
    my $regex  = PRIVATE_FIELDS();
    foreach (sort keys %$self){;
        if($_ !~ /^$regex/){
           $attributes[@attributes] = [$_, $self->{$_}]
        }
    }
    return @attributes;
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
# Convenience method, returns string scalar value dereferenced (a copy) of the property value.
##
sub val {
    my $self = shift;
    my $ret =  $self->{'#'};          # Standard value
       $ret =  $self->{'*'} if !$ret; # Linked value
       $ret = _evaluate($self->{'&'}) if !$ret and exists $self->{'&'}; # Evaluated value
    if(!$ret && $self->{'@$'}){ #return from subproperties.
        my $buf;
        my @arr = @{$self->{'@$'}};
        foreach my $node(@arr){
           $buf .= $node -> val() ."\n";
        }
        return $buf;
    }
    if(ref($ret) eq 'SCALAR'){
           $ret = $$ret;
    }
    return $ret
}

    my $meta =  meta(SHELL());
    sub _evaluate {
        my $value = shift;
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

#

###
# Search select nodes based on from a path statement.
# It will always return an array for even a single subproperty with a passed path ending with (/*).
# The reason is several subproperties of the same name can be contained as elements of this node.
# It will return an array of list values with (@@).
# Or will return an array of its shallow list of child nodes with (@$).
# Or will return an scalar value of an attribute or an property with (#).
# NOTICE - 20221222 Future versions might provide also for more complex path statements with regular expressions enabled.
###
sub find {
    my ($self, $path, $ret, $prev, $seekArray,$ref)=@_;  my @arr;
    foreach my $name(split(/\//, $path)){
        if( $name eq "*" && @arr){
            return  \@arr # The path instructs to return an array, which is set but return is set to single only found element.
        }
        elsif(ref($self) eq "ARRAY"){
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
                if ($name eq '@@') {
                    $ret = $self->{'@@'}; $seekArray = 1;
                    next
                }elsif($name eq '@$') {
                    $ret = $self->{'@$'}; # This will initiate further search in subproperties names.
                    next
                }elsif($name eq '#'){
                    return $ret->val()
                }elsif(exists $self->{$name}){
                    $ret = $self->{$name};
                    next
                }
                   $ref =  ref($ret);
                if(!$seekArray && $ref eq 'ARRAY'){ # ret can be an array of parent same name elemenents.
                   foreach my$n(@$ret) {
                     if ($n->node($name)){
                         $ret = $n; last
                     }
                   }### TODO - Search further elements if not found. Many to many.
                }elsif($ref eq "CNFNode" && $seekArray){
                    $ret = $ret->{$name};
                    next
                }else{
                    if (!$seekArray){
                         # This will initiate further search in subproperties names.
                          $ret = $self->{'@$'};
                          @arr = ();
                    }
                }
        }
           $ref =  ref($ret);
        if($ret && $ref eq 'ARRAY'){
            my $found = 0;           
            undef $prev;
            foreach my $ele(@$ret){
                if($seekArray && exists $ele->{'@$'}){
                    foreach my$node(@{$ele->{'@$'}}){
                        if ($node->{'_'} eq $name){
                            $arr[@arr] = $ele = $node;
                        }
                    }
                    if(@arr>1){
                       $ret = \@arr;
                    }else{
                       $ret = $ele
                    }
                    $found++;
                }elsif (ref($ele) eq "CNFNode"){
                    if($ele->{'_'} eq $name){
                        if ($prev) {
                            $arr[@arr] = $ele;
                            $self      = \@arr;
                            $prev      = $ele;
                        }
                        else {
                            $arr[@arr] = $ele;
                            $prev = $self = $ele;
                        }
                        if ( !$found ) {
                            $self = $ret = $ele;
                        }
                        else {
                            $ret = \@arr;
                        }
                        $found = 1
                    }elsif(exists $ele->{$name}){
                        $ret = $ele->{$name};
                        $found = 1
                    }
                }
            }
            if(!$found && $name ne '@$' && exists $self->{$name}){
                $ret = $self->{$name}
            }else{
                undef $ret if !$found
            }
        }
        elsif($name && $ref eq "CNFNode"){
              $ret  =  $ret -> {$name}
        }
    }
    return !$ret?\@arr:$ret;
}
###
# Similar to find, put simpler node by path routine.
# Returns first node found based on path.
###
sub node {
    my ($self, $path, $ret)=@_;
    if($path !~ /\//){
       return $self->{$path} if exists $self->{$path};
       $ret = $self->{'@$'};
       if($ret){
            foreach(@$ret){
                if ($_->{'_'} eq $path){
                    return $_;
                }
            }
       }
      return
    }
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

###
# Outreached subs list of collected node links found in a property.
my  @linked_subs;

###
# The parsing guts of the CNFNode, that from raw script, recursively creates and tree of nodes from it.
###
sub process {

    my ($self, $parser, $script)=@_;
    my ($sub, $val, $isArray,$isShortifeScript,$body) = (undef,0,0,0,"");
    my ($tag,$sta,$end)=("","",""); my $meta_shortife = &meta_node_in_shortife;
    my ($opening,$closing,$valing)=(0,0,0);
    my @array;

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
                my $isShortife = ($ln =~ s/($meta_shortife)/""/sexi);
                if($ln =~ /^([<>\[\]])(.*)([<>\[\]])$/ && $1 eq $3){
                   $sta = $1;
                   $tag = $2;
                   $end = $3;
                   $isShortifeScript = 1 if $isShortife;
                   my $isClosing = ($sta =~ /[>\]]/) ? 1 : 0;
                   if($tag =~ /^([#\*\@]+)[\[<](.*)[\]>]\/*[#\*\@]+$/){#<- The \/ can sneak in as included in closing tag.
                        if($1 eq '*'){
                            my $link = $2;
                            my $rval = $self  -> obtainLink($parser, $link);
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
                                        $self->{'@$'}  = \@nodes;
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
                   }elsif($tag =~ /^(.*)[\[<]\/*(.*)[\]>](.*)$/ && $1 eq $3){
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
                    }elsif($isClosing){
                        $opening--;
                        $closing++;
                    }else{
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
                                my $property = CNFNode->new({'_'=>$sub, '@' => \$self});
                                my $a = $isArray;
                                if($isShortifeScript){
                                    my ($sub,$prev,$cnt_nl,$bck_p);
                                    while ($body =~ /    (.*)__+   ([\\\|]|\/*)  |  (.*)[:=](.*) | (.*)\n/gmx){
                                        my @sel =  @{^CAPTURE};
                                           if(defined $sel[0]){
                                                if ($sel[1]){
                                                    my $t = substr $sel[1],0,1;
                                                    $bck_p=length($sel[1]);
                                                    my $parent = $sub;
                                                    if($t eq '\\'){
                                                        $parent = $sub ? $sub : $property;
                                                    }elsif($t eq '|'){
                                                        $parent = $sub ? $sub->parent() : $prev;
                                                    }elsif($t eq '/') {
                                                        $parent = $sub;
                                                        do{$parent = $parent -> parent() if $parent -> parent()}while(--$bck_p>0);
                                                        if ($sel[0] eq ''){
                                                            $sub = $parent; next
                                                        }
                                                    }
                                                    $sub = CNFNode->new({'_'=>$sel[0], '@' => $parent});
                                                    my @elements = exists $parent -> {'@$'} ? $parent -> {'@$'} : ();
                                                    $elements[@elements] = $sub; $prev = $parent; $cnt_nl = 0;
                                                    $parent -> {'@$'} = \@elements;
                                                }
                                           }
                                           elsif (defined $sel[2] && defined $sel[3]){
                                                  my $attribute = $sel[2]; $attribute =~ s/^\s*|\s*$//g;
                                                  my $value     = $sel[3]; $value =~ s/^\s*|\s*$//g;
                                                  if($sub){
                                                     $sub      -> {$attribute} = $value
                                                  }else{
                                                     $property -> {$attribute} = $value
                                                  }
                                                 $cnt_nl = 0;
                                           }
                                           elsif (defined  $sel[4]){
                                                  if ($sel[4] eq ''){
                                                        if(++$cnt_nl>1){ #cancel collapse chain and at root of property that is shorted.
                                                            ##$sub = $property ;
                                                            $cnt_nl =0
                                                        }
                                                        next
                                                  }elsif($sel[4] !~ /^\s*\#/ ){
                                                        my $parent = $sub ? $sub->parent() : $property;
                                                        if (exists $parent->{'#'}){
                                                                $parent->{'#'} .= "\n" . $sel[4]
                                                            }else{
                                                                $parent->{'#'} = $sel[4]
                                                        }
                                                    # $sub ="";
                                                  }
                                            }
                                    }#while
                                    $isShortifeScript = 0;
                                }else{
                                    $property -> process($parser, $body);
                                 }
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
                }elsif($opening==0 && $ln =~ /^([<\[])(.+)([<\[])(.*)([>\]])(.+)([>\]])$/ &&
                              $1 eq $3 && $5 eq $7 ){ #<- tagged in line
                        if($2 eq '#') {
                            if($val){$val = "$val $4"}
                            else{$val = $4}
                        }elsif($2 eq '*'){
                                my $link = $4;
                                my $rval = $self  -> obtainLink($parser, $link);
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
                    my @attr = ($ln =~ m/([\s\w]*?)\s*[=:]\s*(.*)\s*/);
                    if(@attr>1){
                        my $n = $attr[0];
                        my $v = $attr[1];
                        if($v =~ /[<\[]\*[<\[](.*)[]>\]]\*[>\]]/){
                           $v = $self-> obtainLink($parser, $1)
                         } $v =~ m/^(['"]).*(['"])$/g;
                           $v =~ s/^$1|$2$//g if($1 && $2 && $1 eq $2);
                        $self->{$n} = $v;
                        next;
                    }else{
                       $val = $ln if $val;
                    }
                }
                                    # Very complex rule, allow #comment lines in buffer withing an node value tag, ie [#[..]#]
                $body .= qq($ln\n)  #if !$tag &&  $ln!~/^\#/ || $tag eq '#'
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
        }
    }
    $ret = $parser->obtainLink($link) if !$ret;
    return $ret;
}

###
# Validates a script if it has correctly structured nodes.
#
sub validate {
    my $self = shift;
    my ($tag,$sta,$end,$lnc,$errors)=("","","",0,0);
    my (@opening,@closing,@singels);
    my ($open,$close) = (0,0);
    my @lines = defined $self -> script() ? split(/\n/, $self->script()) :();
    foreach my $ln(@lines){
        $ln =~ s/^\s+|\s+$//g;
        $lnc++;
        #print $ln, "<-","\n";
        if(length ($ln)){
            #print $ln, "\n";
            if($ln =~ /^([<>\[\]])(.*)([<>\[\]])(.*)/ && $1 eq $3){
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
                    _brk($o).' ln: '.$o->{L}.' idx: '.$o->{idx}.
                    ' wrongly matched with '._brk($c).' ln: '.$c->{L}.' idx: '.$c->{idx}."\n";
             $errors++;
          }
       }
    }
    return  $errors;
}

    sub _brk{
        my $t = shift;
        return 'tag: \''.$t->{S}.$t->{T}.$t->{S}.'\''
    }
###
# Compare one node with  another if is equal in structure.
##
sub equals {
    my ($self, $node, $ref) = @_; $ref = ref($node);
    if (ref($node) eq 'CNFNode'){
        my @s = sort keys %$self;
        my @o = sort keys %$node;
        my $i=$#o;
        foreach (0..$i){
            my $n = $o[$i-$_];
            if($n eq '~' || $n eq '^'){
               splice @o,$i-$_,1;
            }
        }
        $i=$#s;
        foreach (0..$i){
            my $n = $s[$i-$_];
            if($n eq '~' || $n=~/^CNF_/ || $n=~/^DO_/){
               splice @s,$i-$_,1;
            }
        }$i=0;
        if(@s == @o){
           foreach(@s) {
             if($_ ne $o[$i++]){
                return 0
             }
           }
           if($self -> {'@$'} && $node -> {'@$'}){
              @s = sort keys @{$self -> {'@$'}};
              @o = sort keys @{$node -> {'@$'}};
              $i = 0;
              foreach(@s) {
                if($_ ne $o[$i++]){
                    return 0
                }
              }
           }
           return 1;
        }
    }
    return 0;
}

1;