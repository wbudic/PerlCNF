###
# Ambitious Markup Script converter from  MD scripts to HTML.
# MD scripts can thus be placed in PerlCNF properties for further processing by this plugin.
# Processing of these is placed in the data parsers data.
# Programed by  : Will Budic
# Notice - This source file is copied and usually placed in a local directory, outside of its project.
# So it could not be the actual or current version, can vary or has been modiefied for what ever purpose in another project.
# Please leave source of origin in this file for future references.
# Source of Origin : https://github.com/wbudic/PerlCNF.git
# Documentation : Specifications_For_CNF_ReadMe.md
# Open Source Code License -> https://choosealicense.com/licenses/isc/
#
package MarkdownPlugin;

use strict;
use warnings;
no warnings qw(experimental::signatures);
use Syntax::Keyword::Try;
use Exception::Class ('MarkdownPluginException');
use feature qw(signatures);
use Date::Manip;
##no critic ControlStructures::ProhibitMutatingListFunctions

use constant VERSION => '1.0';

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


sub new ($class, $fields={Language=>'English',DateFormat=>'US'}){      

    if(ref($fields) eq 'REF'){
       warn "Hash reference required as argument for fields!"
    }
    my $lang =   $fields->{'Language'};
    my $frmt =   $fields->{'DateFormat'};
    Date_Init("Language=$lang","DateFormat=$frmt");            
    $fields->{'disk_load'} = 0 if not exists $fields->{'disk_load'};
   
    return bless $fields, $class
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
            $class = $tag;
            $tag = 'div';
        }else{
            $tag = 'pre' if($tag eq 'sh' or $tag eq 'bash');
        }
        if($tag eq 'perl'){
            $class='perl'; 
            $tag  ='div';                                   
        }
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
        if($ln =~ /^```(\w*)\s(.*)```$/g){
            $tag = $1; 
            $ln  = $2; $list_end=0;
            my @code_tag = @{ setCodeTag($tag, "") }; 
            $buff .= qq(<$code_tag[1] class='$code_tag[0]'>$ln</$code_tag[1]>\n);
            next
        }elsif($ln =~ /^\s*```(\w*)/){
            my $bfCode; 
            if(!$tag){
                my @code_tag = @{ setCodeTag($1, $1) };
                $class = $code_tag[0];         
                $tag = $code_tag[1] if !$tag;
            }
            if($code){
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
                     $bfCode .= '<h1><span class="cnf"><a title="M.C. Hammer -- Can\'t  touch this!" href="/" style="text-decoration: none;">'.uc($class).'</a></span></h1>'
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
                $buff .= "$bfCode\n";
            }
        }elsif(!$code && $ln =~ /^\s*(#+)\s*(.*)/){
            my $h = 'h'.length($1);
            my $title = $2; 
            $titels[@titels] = {$lnc,$title};
            if($list_root){ # Has been previously gathered and hasn't been buffered yet.
               $buff .= $list_root -> toString();
               undef $list_root;
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
                $bqte_tag = "ul";
            }elsif($2){
                $bqte_tag = "ol";
            }else{
                $bqte_tag = "p";
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
                   $bqte .= ${style($ln)}."</br>";
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
            if($code){
                 my $v=$2; my $spc=$1; $list_end =0;
                if($tag eq 'pre' && $code == 1){
                    $v =~ s/</&#60;/g;
                    $v =~ s/>/&#62;/g;
                    $para .= "$v\n"; 
                }elsif($code == 2){
                    if($ln =~/^\s*\<+.*>+$/){
                       $para .= inlineCNF($v,$spc)."<br>\n"                                        
                    }else{
                       $para .= code2HTML($v)."<br>\n"
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
                    while($bqte_nested-->0){$bqte .="</$bqte_tag></blockqoute>\n"}
                    $para   .= $bqte;
                    undef $bqte;
                }
                $para .= ${style($2)}."\n"         
            }
        }else{            
            if($list_root && ++$list_end>1){
               $buff .= $list_root -> toString();
               undef $list_root;
            }
            elsif($para){
                if($list_item){
                   $list_item->{item} = $list_item->{item} .  $para;
                   $list_end=0;
               }
               elsif($code){
                    $buff .= $para;
               }else{
                    $buff .= qq(<p>$para</p><br>\n);
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
    my $v=$val;
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
        
        return $v
}

sub inlineCNF($v,$spc){
 $spc =~ s/\s/&nbsp;/g;
 $v =~ m/ (<{2,3})(.*?)(>{2,3}) (.*)   /gmx;
 my $oo = $1;
 my $body = $2;
 my $cc = $3;
 my $restIfAny = $4; $restIfAny="" if not $restIfAny;

if (!$body){
    $oo=$cc="";  $body=$v;$v=~/^(<+)/;$oo=$1 if$1;
    if($v=~m/\[\#\[/){
        return "$spc<span ".C_PV.">[#[</span>"
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
        $v=~/(>+)$/;if($1){
        $cc=$1;
         #$body =~ s/>/&#62;/g;  
        }else{
            $oo =~ s/</&#60;/g;
            if($v=~m/<<<(.*)/){
              return "<span ".C_B.">$oo</span><span ".C_PI.">$1</span>"
            }elsif($v=~m/^(<{2,3})(.*?)([><])(.*)/){                
              return "$spc<span ".C_B.">$oo</span><span ".C_PN.">$1</span>><span ".C_B.">$2</span><span ".C_PI.">$3</span>";                
            }else{
              return propValCNF($v)
            }
        }
    }
}
    $oo =~ s/</&#60;/g;
    $cc =~ s/>/&#62;/g;     
    $body =~ m/ ([@%]<)  ([\$@%]?\w+) ([<>])  |                  
                ([^<>]+) ([><])? (.*)
            /gmx;

    if($4&&$5&&$6){
        my ($o,$var,$val, $prop);
        $var  = $4; $o=$5; $val=$6;   
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
    elsif($4){
        my $t = $4;
        if(!$6){
           $t =~ /(\w+)\s+(.*)/;
           my $i = $1;
            if($PARSER->isReservedWord($i)){
                    $i = "<span ".C_PI.">$i</span>"
            }else{
                    $i = "<span ".C_PA.">$i</span>"
            }
           my $prop = propValCNF($2);
           $v = "<span ".C_B.">$oo</span>$i</span>$prop<span ".C_B.">$cc</span>"
        }else{
            my $i = $6;
            my $c = $7; $c = $8 if !$c;
            $t =~ s/</&#60;/g; 
            $c =~ s/>/&#62;/g if $c;
            $v = "<span C_B>$t</span><span ".C_PI.">$i</span>$c";
        }
    }            
    elsif($1 && $2 && $3){
        my $ins  = $2;
        my $prop = propValCNF($3);
        $v = "<span ".C_B.">$oo</span>$ins<\/span>$prop<span ".C_B.">$cc</span>"
    }
    return $spc.$v.$restIfAny
}


sub propValCNF($v){    
    $v =~ m/(.*)([=:])(.*)/gs;
    if($1&&$2&&$3){
      return "&nbsp;<span ".C_PN.">$1</span><span class='O'>$2</span><span ".C_PV.">$3</span>";
    }else{
       return "&nbsp;<span ".C_PV.">$v</span>";
    }
    return $v;
}

sub style ($script){
    MarkdownPluginException->throw(error=>"Invalid argument passed as script!",show_trace=>1) if !$script;
    #Links <https://duckduckgo.com>
    $script =~ s/<(http[:\/\w.]*)>/<a href=\"$1\">$1<\/a>/g;
    $script =~ s/(\*\*([^\*]*)\*\*)/\<em\>$2<\/em\>/gs;
    if($script =~m/[<\[]\*[<\[](.*)[\]>]\*[\]>]/){#It is a CNF link not part of standard Markup.
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

/;



1;