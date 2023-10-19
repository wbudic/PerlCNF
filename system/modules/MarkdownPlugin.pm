###
# This is an Ambitious Markup Script converter from  MD scripts to HTML. Every programers nightmare.
# MD scripts can thus be placed in PerlCNF properties for further processing by this plugin.
# Processing of these is placed in the data parsers data.
#
package MarkdownPlugin;

use strict;
use warnings;
no warnings qw(experimental::signatures);
use Syntax::Keyword::Try;
use Exception::Class ('MarkdownPluginException');
use feature qw(signatures);
use Clone qw(clone);
##no critic ControlStructures::ProhibitMutatingListFunctions

use constant VERSION => '1.1';

our $TAB = ' 'x4;
our $PARSER;
###
# Constances for CSS CNF tag parts. See end of this file for package internal provided defaults CSS.
###
use constant {
    C_B  => "class='B'",  #CNF TAG angle brackets identifiers.
    C_PN => "class='pn'", #Prop. name.
    C_PI => "class='pi'", #Prop. instruction.
    C_PV => "class='pv'", #Prop. value.
    C_PA => "class='pa'"  #Anon, similar to prop. name.
};


sub new ($class, $plugin){
    my $settings;
    if($plugin){
       $settings = clone $plugin; #clone otherwise will get hijacked with blessings.
    }
    $settings->{'disk_load'} = 0 if not exists $settings->{'disk_load'};
    return bless $settings, $class
}

###
# Process config data to contain expected fields and data.
###
sub convert ($self, $parser, $property) {
try{
    my ($item, $script) =  $parser->anon($property);
    $PARSER = $parser;
    die "Property not found [$property]!" if !$item;

    my $ref = ref($item); my $escaped = 0; $script = $item;
    if($ref eq 'CNFNode'){
       $script = $item->{script}
    }elsif($ref eq 'InstructedDataItem'){
       $script = $item->{val};
       $escaped = $item->{ins} eq 'ESCAPED'
    }elsif($script !~ /\n/ and -e $script ){
        my $file = $parser->anon($property);
        $script = do {
        open my $fh, '<:encoding(UTF-8)', $script or MarkdownPluginException->throw("File not avaliable: $script");
        local $/;
        <$fh>;
        };
    }
    if($escaped){
        $script =~ s/\\</</gs;
        $script =~ s/\\>/>/gs;
        #$script =~ s/\n/<br>/gs;
    }
    my @doc = @{parse($self,$script)};
    $parser->data()->{$property} =  $doc[0];
    $parser->data()->{$property.'_headings'} = $doc[1];

}catch($e){
        MarkdownPluginException->throw(error=>$e ,show_trace=>1);
}}

###
# Helper package to resolve the output of HTML lists in order of apperance in some MD script.
# It is a very complex part of the parsing algorithm routine.
# This mentioned, here look as the last place to correct any possible translation errors.
# @CREATED 20230709
# @TODO possible to be extended ot account for CSS specified bullet types then the HTML default.
###
package HTMLListItem {
    sub new{
        my $class = shift;
        my ($type,$item,$spc) = @_;
        my @array = ();
        return bless{type=>$type,item=>$item,spc=>$spc,list=>\@array},$class;
    }
    sub parent($self) {
        return  exists($self->{parent}) ? $self->{parent} : undef
    }
    sub add($self, $item){
        push @{$self->{list}}, $item;
        $item ->{parent} = $self;
    }
    sub hasItems($self){
        return @{$self->{list}}>0
    }
    sub toString($self){
        my $t = $self->{type};
        my $isRootItem = $self -> {spc} == 0 ? 1 : 0;
        my $hasItems   = $self->hasItems();
        my $hasParent  = exists($self->{parent});
        my $ret = "";
        if ($hasItems) {
            if($isRootItem){
                $ret = "<$t>\n"
            }
            if($self->{item}){
                $ret = "<li>".$self -> {item}."\n<$t>\n"
            }
        }else{
            return  "<li>".$self -> {item}."</li>\n"
        }
        foreach my $item(@{$self->{list}}){
            if($item->hasItems()){
               $ret .= $item->toString();
            }else{
               my $it = $item->{type};
               $it = 'li' if $it eq 'ol' || $it eq 'ul';
               $ret .= "<$it>".$item->{item}."</$it>\n";
            }
        }
        if($hasItems){
             $ret .= "</$t>\n";
             $ret .= "</li>\n" if !$isRootItem;
        }
        return $ret
    }
}

sub setCodeTag($tag, $class){
    if($tag){
        $tag = lc $tag;
        if($tag eq 'html' or $tag eq 'cnf' or $tag eq 'code' or $tag eq 'perl'){
            $class = $tag if !$class;
            $tag = 'div' if $tag ne 'code';
        }elsif($tag eq 'perl'){
            $class='perl' if !$class;
            $tag  ='div';
        }elsif($tag eq 'mermaid'){
            $class = $tag;
            $tag="pre";
        }else{
            $tag = 'pre' if($tag eq 'sh' or $tag eq 'bash');
        }
        $class = lc $class; #convention is that style class to be all lower case like tags.
    }else{
        $tag = $class = 'pre';
    }
    return [$class, $tag]
}

sub parse ($self, $script){
try{
    my ($buff, $para, $ol, $lnc);
    my $list_end; my $ltype=0;  my $nix=0; my $nplen=0; my $list_item; my $list_root;
    my @titels;my $code = 0; my ($tag, $class);  my $pml_val = 0;  my ($bqte, $bqte_nested,$bqte_tag);
    $script =~ s/^\s*|\s*$//;
    foreach my $ln(split(/\n/,$script)){
           $ln =~ s/\t/$TAB/gs; $lnc++;
        if($ln =~ /(.*) `{3}(\w*)\s*(.*)`{3}  (.*)/gx){
            my $pret = ""; $pret = $1 if $1;
            my $post = ""; $post = $4 if $4;
            $tag = 'code'; $tag =$2 if $2;
            my $inline = $3;
            $inline = inlineCNF($inline,"");
            my @code_tag = @{ setCodeTag($tag, "") };
            $ln = qq($pret<$code_tag[1] class='$code_tag[0]'>$inline</$code_tag[1]>$post\n);
            undef $tag;
            if(!$pret && !$post){
                $buff .= $ln; next;
            }elsif($list_item){
                my $new = HTMLListItem->new('dt', $ln, $list_item->{spc});
                $list_item ->add($new);
                next;
            }
        }
        elsif($ln =~ /^\s*```(\w*)(.*)/){
            my $bfCode; my $pretext = $2; $pretext ="" if !$2; $pretext .= "<br>" if $pretext;
            if(!$tag){
                my @code_tag = @{ setCodeTag($1, $1) };
                $class = $code_tag[0];
                $tag = $code_tag[1] if !$tag;
            }
            if($code>0){
               if($para){
                  $bfCode .= "$para\n"
               }
               $bfCode .= "</$tag>"; undef $para;
               $code = 0; undef $tag;
               if($list_item){
                  $list_item -> {item} = $list_item -> {item} . $bfCode.'<br>';
                  $list_item =  $list_item -> parent();
                  next;
               }
            }else{
               $bfCode .= "<$tag class='$class'>";
               if($class eq 'perl'){
                  $bfCode .= qq(<h1><span>Perl</span></h1>);
                  $code = 2;
                }else{
                  if($class eq 'cnf' or $class eq 'html'){
                     $bfCode .= "<h1><span class='cnf'>
                     <a title='M.C. Hammer -- Can\'t  touch this!' href='/' style='text-decoration: none;'>".uc($class).
                     q(</a></span></h1>).$pretext
                  }
                  $code = 1
                }
            }
            if($list_item){
                my $new = HTMLListItem->new('dt', "<br>$bfCode", $list_item ->{spc});
                $list_item -> add($new);
                $list_item =  $new;
                $list_end=0;
            }else{
                $buff .= "$bfCode\n$pretext";
            }
            next
        }
        if(!$code && $ln =~ /^\s*(#+)\s*(.*)/){
            my $h = 'h'.length($1);
            my $title = $2;
            $titels[@titels] = {$lnc,$title};
            if($list_root){ # Has been previously gathered and hasn't been buffered yet.
               $buff .= $list_root -> toString();
               undef $list_root;
               undef $list_item;
            }
            $buff .= qq(<$h>$title</$h><a name=").scalar(@titels)."\"></a>\n"
        }
        elsif(!$code &&  ($ln =~ /^(\s*)(\d+)\.\s(.*)/ || $ln =~ /^(\s*)([-+*])\s(.*)/)){
            my $spc = length($1);
            my $val = $3 ? ${style($3)} : "";
            my $new = HTMLListItem->new(($2=~/[-+*]/?'ul':'ol'), $val, $spc);
            if(!$list_root){
                $list_end = 0;
                $list_root = HTMLListItem->new($new->{type});
                $list_root -> add($new);
                $list_item = $new
            }elsif($spc>$nplen){
                $list_item -> add($new);
                $list_item = $new;
                $nplen = $spc;
            }else{
               my $isEq = $list_item->{spc} == $spc;
               while($list_item->{spc} >= $spc && $list_item -> parent()){
                     $list_item = $list_item -> parent();
                     last if $isEq
               }
               $list_item = $list_root if  !$list_item;
               $list_item -> add($new);
               $list_item = $new;
            }
            $list_end = 0;
        }elsif(!$code && $ln =~ /(^|\\G)[ ]{0,3}(>+) ?/){
            my $nested = length($2);
             $ln =~ s/^\s*\>+//;
            ($ln =~ /^(\s+)   (\d+) \.\s (.*)/x || $ln =~ /^(\s*) ([-+*]) \s(.*)/x);
            if($2 && $2 =~ /[-+*]/){
                $bqte_tag = "ul"
            }elsif($2){
                $bqte_tag = "ol"
            }else{
                $bqte_tag = "p"
            }
            if(!$bqte_nested){
                $bqte_nested = $nested;
                $bqte .="<blockquote><$bqte_tag>\n"
            }elsif($bqte_nested<$nested){
                $bqte .="</$bqte_tag><blockquote><$bqte_tag>";
                $bqte_nested = $nested;
            }elsif($bqte_nested>$nested){
                $bqte .="</$bqte_tag></blockquote><$bqte_tag>";
                $bqte_nested--;
            }
            if($ln !~ /(.+)/gm){
               $bqte .= "\n</$bqte_tag><p>\n"
            }else{
                if($bqte_tag eq 'p'){
                   $ln =~ s/^\s*//g;
                   $bqte .= ${style($ln)}."<br>";
                }else{
                   $ln =~ s/^\s*[-+*]\s*|^\s*\d+\.\s*//g;
                   $bqte .= "<li>".${style($ln)}."</li>\n";
                }
            }
        }
        elsif(!$code && $ln =~ /^\s*\*\*\*/){
            if($para){
                $para .= qq(<hr>\n)
            }else{
                $buff .= qq(<hr>\n)
            }
        }
        elsif($ln =~ /^(\s*)(.*)/ && length($2)>0){
            my $spc = length($1);
            my $v = $2;
            if($code){
                 my $spc=$1; $list_end =0;
                if($tag eq 'pre' && $code == 1){
                    $v =~ s/</&#60;/g;
                    $v =~ s/>/&#62;/g;
                    $para .= "$v\n";
                }elsif($code == 2){
                    if($ln =~/^\s*\<+.*>+$/){
                       $para .= inlineCNF($v,$spc)."<br>\n"
                    }else{
                       $spc =~ s/\s/&nbsp;/g;
                       $para .= $spc.code2HTML($v)."<br>\n"
                    }
                }else{
                    $v = inlineCNF($v,$spc);
                    if(length($v) > length($ln)){
                       $para .= qq($v<br>);
                       next
                    }

                    $v =~ m/  ^(<{2,3}) ([\$@%]*\w*)$
                            | ^(>{2,3})$
                            | (<<) ([\$@%]*\w*) <(\w+)>
                     /gx;

                    if($1&&$2){
                        my $t = $1;
                        my $i = $2;
                        $t =~ s/</&#60;/g;
                        $para .= "<span ".C_B.">$t</span><span ".C_PI.">$i</span><br>";
                        $pml_val = 1;
                        next;
                    }elsif($3){
                        my $t = $3;
                        $t =~ s/>/&#62;/g;
                        $para .= "<span C_B>$t</span><br>\n";
                        $pml_val = 0;
                        next;
                    }elsif($4&&$5&&6){
                        my $t = $4;
                        my $v = $5;
                        my $i = $6;
                        $t =~ s/</&#60;/g;
                        $para .= "<span ".C_B.">$t</span><span ".C_PV.">$v</span>".
                                    "<span ".C_B.">&#60;</span><span ".C_PI.">$i</span><span ".C_B."&#62;</span><br>";
                        $pml_val = 1;
                        next;
                    }

                    $v =~ m/ ^(<<)  ([@%]<) ([\$@%]?\w+) ([<>])
                            |^(<{2,3})
                                ([\$@%\w]+)\s*
                                      <*([^>]+)
                              (>{2,3})$

                           /gx;# and my @captured = @{^CAPTURE};

                    if($5&&$6&&$7&&$8){
                        my $t = $5;
                        my $v = $6;
                        my $i = $7;
                        my $c = $8;
                        $t =~ s/</&#60;/g;
                        $c =~ s/>/&#62;/g;
                        $pml_val = 1;
                        $para .= "<span".C_B.">$t</span><span ".C_PV.">$v</span><span C_B>&#60;</span><span class='pi'>$i</span><span ".C_B.">$c</span><br>";

                    }elsif($5&&$6){
                        my $t = $5;
                        my $i = $6;
                        $t =~ s/</&#60;/g; $pml_val = 1;
                        $para .= "<span ".C_B.">$t</span><span class='pi'>$i</span><br>";
                    }elsif($1 && $2 && $3){
                        $pml_val = 1;
                        $para .= "<span ".C_B.">&#60;&#60;$2<\/span><span ".C_PV.">$3</span><span ".C_B.">&#62;</span><br>";
                    }elsif($8){
                        my $t = $8;
                        $t =~ s/>/&#62;/g;  $pml_val = 0;
                        $para .= "<span ".C_B.">$t</span><br>\n";
                    }
                    else{
                        if($pml_val){
                            $v =~ m/(.*)([=:])(.*)/gs;
                            if($1&&$2&&$3){
                                $para .= "<span ".C_PV.">$1</span><span C_B>$2</span><span ".C_PN.">$3</span> <br>\n";
                            }else{
                                $para .= " <span ".C_PN.">$v</span><br>\n";
                            }
                        }else{
                            $para .= "$v<br>\n";
                        }
                    }
                }
            }else{
                if($bqte){
                    while($bqte_nested-->0){$bqte .="</$bqte_tag></blockquote>\n"}
                    $para   .= $bqte; $bqte_nested=0;
                    undef $bqte;
                }
                if($list_root && $spc>0){
                    my $new = HTMLListItem -> new('dt', ${style($v)}, $spc);
                    if($spc>$nplen){
                        $list_item -> add($new);
                        $list_item = $new;
                        $nplen = $spc;
                    }else{
                        my $isEq = $list_item->{spc} == $spc;
                        while($list_item->{spc} >= $spc && $list_item -> parent()){
                            $list_item = $list_item -> parent();
                            last if $isEq
                        }
                        $list_item = $list_root if  !$list_item;
                        $list_item -> add($new);
                    $list_item = $new;
                    }
                    $list_end = 0;
                }else{
                    $para .= ${style($v)}."\n"
                }
            }
        }else{
            if($list_root && ++$list_end>1){
               $buff .= $list_root -> toString();
               if($para){
                    $buff .= qq(<p>$para</p>\n);
                    $list_end=0;
                    $para  =""
               }
               undef $list_root;
               undef $list_item;
            }
            elsif($para){
                if($bqte){
                    while($bqte_nested-->0){$bqte .="</$bqte_tag></blockquote>\n"}
                    $para   .= $bqte;
                    undef $bqte;
                }
                if($list_item){
                   $list_item->{item} = $list_item->{item} .  $para;
                   $list_end=0;
               }
               elsif($code){
                    $buff .= $para;
               }else{
                    $buff .= qq(<p>$para</p>\n);
               }
               $para=""
            }
        }
    }
    if($bqte){
       while($bqte_nested-->0){$bqte .="\n</$bqte_tag></blockquote>\n"}
       $buff .= $bqte;
    }
    if($list_root){
       $buff .= $list_root-> toString();
    }
    $buff .= qq(<p>$para</p>\n) if $para;
return [\$buff,\@titels]
}catch($e){
        MarkdownPluginException->throw(error=>$e ,show_trace=>1);
}}

sub code2HTML($val){
    my ($v,$cmnt)=($val,"");

    $v =~ s/(.*?)(\#.*)/<span class='cmnt'>$2<\/span>/g;
    if($1 && $2 && $1!~ m/\s+/){
        $v = $1; $cmnt = "<span class='cmnt'>$2<\/span>";
    }else{
        return $v if defined $2 and $2 ne $v;
    }

    my @strs = ($v =~ m/(['"].*?['"])/g);
    foreach(0..$#strs){
        my $r = $strs[$_]; $r =~ s/\[/\\[/;
        $PARSER->log($r);
        my $w = "\f$_\f";
        $v =~ s/$r/$w/ge;
    }

    $v =~ s/([,;=\-\+]+)/<span class='opr'>$1<\/span>/gx;
    $v =~ s/(my|our|local|do|use|lib|require|new|while|for|foreach|while|if|else|elsif|eval)/<span class='kw'>$1<\/span>/g;
    $v =~ s/(\$\w+)/<span class='var'>$1<\/span>/g;
    $v =~ s/([\(\)\{\}\[\]] | ->)/<span class='bra'>$1<\/span>/gx;

    foreach(0..$#strs){
        my $w = $strs[$_];
        $w =~ s/(^['"])(.*)(['"]$)/<span class='Q'>$1<\/span><span class='str'>$2<\/span><span class='Q'>$3<\/span>/g;
        my $r = "\f$_\f";
        $v =~ s/$r/$w/ge;
    }

        return "$v$cmnt";
}

sub inlineCNF($v,$spc){

 $v =~ m/(<{2,3})(.*?)(>{2,3})(.*)/g;
 my $oo = $1;$oo =~s/\s+//;#<- fall through expression didin't match
 my $body = $2;
 my $cc = $3;
 my $restIfAny = $4; $restIfAny="" if not $restIfAny;
 my $len = length($spc); my $spc_o = $spc; $spc_o =~ s/\s/&nbsp;/g;
 if($len>4&&$len<9){$len-=$len-2;$spc = '&nbsp;'x$len}else{$spc =~ s/\s/&nbsp;/g}
 if(!$body){
    $oo=$cc="";  $body=$v;$v=~/^(<+)/;$oo=$1 if$1;
    if($v=~m/\[\#\[/){
        my $r = "<span ".C_PV.">[#[</span>";
           $v =~ s/\[\#\[/$r/g;
        if($v =~ m/\]\#\]/){
           $r = "<span ".C_PV.">]#]</span>";
           $v =~ s/\]\#\]/$r/g;
        }
        return "$spc$v"
    }
    elsif($v=~m/\]\#\]/){
        return "$spc<span ".C_PV.">]#]</span>"
    }
    elsif($v=~m/^\[(\w*)\[/ && $1){
       return "$spc<span ".C_B.">[</span><span ".C_PI.">$1</span><span ".C_B.">[</span>"
    }
    elsif($v=~m/\](\w*)\]/ && $1){
       return "$spc<span ".C_B.">]</span><span ".C_PI.">$1</span><span ".C_B.">]</span>"
    }
    elsif($v=~m/^<{1}(\w*)<{1}/ && $1){
       return "$spc<span ".C_B.">&#60;</span><span ".C_PV.">$1</span><span ".C_B.">&#60;</span>"
    }elsif($v=~m/^>{1}(\w*)>{1}/ && $1){
       return "$spc<span ".C_B.">&#62;</span><span ".C_PV.">$1</span><span ".C_B.">&#62;</span>"
    }elsif($v=~m/^<\*<.*>\*>$/){
        my $r = "<span ".C_B.">&#62;</span><span ".C_PV.">*</span><span ".C_B.">&#62;</span>";
        $body=~s/>\*>$/$r/;
           $r = "<span ".C_B.">&#60;</span><span ".C_PV.">*</span><span ".C_B.">&#60;</span>";
        $body=~s/^<\*</$r/;
        return $spc.$body
    }
    elsif($v eq '>>'){
        return  "$spc<span ".C_B.">&#62;&#62;</span>\n"  }
    else{
        $v=~/(.*)(>+\s*)$/;
        if(!$1 && $2){
            $v = $2; $v =~ s/>/&#62;/g;
            return "$spc<span ".C_B.">$v</span>"
        }else{
            $oo =~ s/</&#60;/g;
            if($v=~m/>>>/){
                $v =~ s/>/&#62;/g; return "<span ".C_B.">$v</span>"
            }elsif($v=~m/<<<(.*)/){
              return "$spc<span ".C_B.">$oo</span><span ".C_PI.">$1</span>"
            }elsif($v=~m/^(<{2,3})(.*?)([><])(.*)/){
                my $t = "$1$2$3";
                my $var = $2;
                my $im = $3;
                my $r = $4;
                my $end =$4;
                if($end){
                    my $changed = ($end =~ s/(>|<)$//g);
                    if($PARSER -> isReservedWord($end)){
                        $v  = "<span ".C_PI.">$end</span>";  $v .= "<span ".C_B.">".($1 eq '<'?"&#60":"&#62")."</span>" if $changed
                    }else{
                        if (!$var){$v = "<span ".C_PA.">$r</span>"}else{$v=""}
                    }
                    if($var =~ /[@%]/){
                        if($r =~ /(.*)([><])(.*)/){
                            $v  = "$spc<span ".C_B.">$t</span><span ".C_PA.">$1</span>";
                            $v .= "<span ".C_B.">$2</span>";
                            $v .= "<span ".C_PV.">$3</span>";
                            return $v;
                        }
                    }else{
                        $v = "$spc<span ".C_B.">$oo</span><span ".C_PN.">$var</span><span ".C_B.">$im</span>$v";
                        if($r =~ /(\w*)\s(.*)/){
                           return "$v<span ".C_PI.">$1</span> <span ".C_PV.">$2</span>$cc"
                        }else{
                           return $v
                        }
                    }
                }else{
                        $v = "<span ".C_B.">$3</span>" if $3;
                }
                return "$spc<span ".C_B.">$oo</span><span ".C_PN.">$2</span><span ".C_B.">$3</span>$v"
            }else{
              return $spc_o.propValCNF($v)
            }
        }
    }
}

if(!$oo && !$cc){

    $body =~ m/ ^([\[<\#\*\[<]+)  (.*?) ([\]>\#\*\]>]+)$  /gmx;
    if($1&&$2&&$3){
      $oo   = $1;
      $body = $2;
      $cc   = $3;
      $oo   =~ s/</&#60;/g;
      $oo   =~ s/>/&#62;/g;
      $cc   =~ s/</&#60;/g;
      $cc   =~ s/>/&#62;/g;
      $body =~ s/</&#60;/g;
      $body =~ s/>/&#62;/g;
      return "$spc<span ".C_B.">$oo</span><span ".C_PV.">$body</span>><span ".C_B.">$cc</span>";
    }

}else{
    $oo =~ s/</&#60;/g;
    $cc =~ s/>/&#62;/g;
}
    $body =~ m/ ([@%<]+)  ([\$@%]?\w+)? ([<>]) (.*) |
                ([^<>]+) ([><])? (.*)
            /gmx;

    if($5&&$6&&$7){
        my ($o,$var,$val, $prop);
        $var  = $5; $o=$6; $val=$7;
        $val  =~ /(.*)(>$)/; if($1&&$2){
            my $v = $1;
            my $i = $2;
            if($PARSER->isReservedWord($v)){
               $v = "<span ".C_PI.">$v</span>"
            }else{
               $v =~ s/(\w+)(\$+)/<span class='pa'>$1<\/span><span class='ps'">$2<\/span>/g;
               $v = "<span ".C_PA.">$i</span>" if !$2;
            }
            $val=$v; $cc = "<span ".C_B.">&#62;</span>";

        }elsif($PARSER->isReservedWord($var)){
                $var = "<span ".C_PI.">$var</span>";
                $val =~ s/</&#60;/g;
                $val =~ s/>/&#62;/g;
        }else{
                $var =~ s/(\w+)(\$+)/<span class='pa'>$1<\/span><span class='ps'">$2<\/span>/g;
                $var = "<span ".C_PA.">$var</span>" if !$2;
                $val =~ s/</&#60;/g;
                $val =~ s/>/&#62;/g;
        }
        my $r = "<span ".C_B.">&#60;</span>";
        $o =~ s/^</$r/ge;
        $r = "<span ".C_B.">&#62;</span>";
        $o =~ s/^>/$r/ge;

        $prop = "$var</span>$o<span ".C_PV.">$val</span>";

        $v = "<span ".C_B.">$oo</span>$prop</span><span ".C_B.">$cc</span>";
    }
    elsif($5){
        my $t = $5;
        if(!$7){
           $t =~ /(\w*)(\\\w*|\s*)(.*)/;
           my $i = $1;
           if($PARSER->isReservedWord($i)){
                    $i = "<span ".C_PI.">$i</span>"
           }else{
                    $i = "<span ".C_PA.">$i</span>"
           }
           my $prop = propValCNF($2.$3);
           $v = "<span ".C_B.">$oo</span>$i</span>$prop<span ".C_B.">$cc</span>"
        }else{
            my $i = $7;
            my $c = $8; $c = $9 if !$c;
            $t =~ s/</&#60;/g;
            $c =~ s/>/&#62;/g if $c;
            $v = "<span C_B>$t</span><span ".C_PI.">$i</span>$c"
        }
    }
    elsif($1 && $2 && $3){
        my $mrk  = $1; $mrk  ="" if !$mrk;
        my $ins  = $2;
        my $prop = propValCNF($3);
        $prop   .= propValCNF($4) if $4;
        $v = "<span ".C_B.">$oo$mrk</span><span ".C_PI.">$ins</span>$prop<span ".C_B.">$cc</span>"
    }elsif($1 && $3 && $4){
        $body = $4;
        $oo .= "$1$3";
        $oo =~ s/</&#60;/g;
        $body =~ /(.*)([><])(.*)/;
        if($1 && $2 && $3){
           $v = "<span ".C_B.">$oo</span><span ".C_PI.">$1</span><span ".C_B.">$2</span><span ".C_PV.">$3</span><span ".C_B.">$cc</span>"
        }else{
           $v = "<span ".C_B.">$oo</span><span ".C_PI.">$body</span><span ".C_B.">$cc</span>"
        }
    }elsif($2){$v = "<span ".C_B.">$v</span>"}
    return $spc.$v.$restIfAny
}


sub propValCNF($v){
    my @match = ($v =~ m/([^:]+)([=:]+)(.*)/gs);
    if(@match){
      return "&nbsp;<span ".C_PI.">$1</span><span ".C_B.">$2</span><span ".C_PI.">$3</span>" if $2 eq '::';
      return "&nbsp;<span ".C_PN.">$1</span><span class='O'>$2</span><span ".C_PV.">$3</span>"
    }
    elsif($v =~ /[><]/){
       return  "<span ".C_B.">$v</span>"
    }else{
       return "<code ".C_PV.">$v</code>"
    }
    return $v;
}

sub style ($script){
    MarkdownPluginException->throw(error=>"Invalid argument passed as script!",show_trace=>1) if !$script;
    #Links <https://duckduckgo.com>
    $script =~    s/<(http[:\/\w.]*)>/<a href=\"$1\">$1<\/a>/g;
    $script =~    s/(\*\*([^\*]*)\*\*)/\<em\>$2<\/em\>/gs;
    if($script =~ m/[<\[]\*[<\[](.*)[\]>]\*[\]>]/){#It is a CNF link not part of standard Markup.
       my $link = $1;
       my $find = $PARSER->obtainLink($link);
       $find = $link  if(!$find);
       $script =~ s/[<\[]\*[<\[](.*)[\]>]\*[\]>]/$find/gs;
    }
    $script =~ s/(\*([^\*]*)\*)/\<strong\>$2<\/strong\>/gs;
    $script =~ s/__(.*)__/\<del\>$1<\/del\>/gs;
    $script =~ s/~~(.*)~~/\<strike\>$1<\/strike\>/gs;
    my $ret = $script;
    # Inline CNF code handle.
    if($ret =~ m/`{3}(.*)`{3}/){
        my $v = inlineCNF($1,"");
        $ret =~ s/```(.*)```/\<span\>$v<\/span\>/;
    }
    #Images
    $ret =~ s/!\[(.*)\]\((.*)\)/\<div class="div_img"><img class="md_img" src=\"$2\"\ alt=\"$1\"\/><\/div>/;
    #Links [Duck Duck Go](https://duckduckgo.com)
    $ret =~ s/\[(.*)\]\((.*)\)/\<a href=\"$2\"\>$1\<\/a\>/;
    return \$ret;
}

###
# Style sheet used  for HTML conversion. NOTICE - Style sheets overide sequentionaly in order of apperance.
# Link with: <*<MarkdownPlug::CSS>*> in a TREE instructed property.
###
use constant CSS => q/

div .cnf {
    background: aliceblue;
}
.cnf h1 span  {
    color:#05b361;
    background: aliceblue;
}
.B {
	color: rgb(247, 55, 55);
	padding: 2px;
}
.Q {
	color: #b217ea;
	font-weight: bold;
}
.pa {
	color: rgb(52, 52, 130);
	font-weight: bold;
}
.pn {
	color: rgb(62, 173, 34);
}
.ps {
	color: rgb(128, 0, 0);
}
.pv {
	color: rgb(136, 58, 200);
}
.pi {
	color: rgb(81, 160, 177);
	;
	font-weight: bold;
}

.kw {
    color: maroon;
    padding: 2px;
}
.bra {color:rgb(247, 55, 55);}
.var {
    color: blue;
}
.opr {
    color: darkgreen;
}
.val {
    color: gray;
}
.str {
    color: orange;
    font-style:italic;
    font-weight: bold;
}
.inst {
    color: green;
    font-weight: bold;
}
.cmnt {
    color: #025802;
    font-style:italic;
    font-weight: bold;
}

/;



1;

=begin copyright
Programed by  : Will Budic
EContactHash  : 990MWWLWM8C2MI8K (https://github.com/wbudic/EContactHash.md)

Open Source Code License -> https://github.com/wbudic/PerlCNF/blob/master/ISC_License.md
=cut copyright