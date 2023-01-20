# Main Parser for the Configuration Network File Format.
# This source file is copied and usually placed in a local directory, outside of its project.
# So not the actual or current version, might vary or be modiefied for what ever purpose in other projects.
# Programed by  : Will Budic
# Source Origin : https://github.com/wbudic/PerlCNF.git
# Documentation : Specifications_For_CNF_ReadMe.md
# Open Source License -> https://choosealicense.com/licenses/isc/
#
package CNFParser;

use strict;use warnings;#use warnings::unused;
use Exception::Class ('CNFParserException'); 
use Syntax::Keyword::Try;
use Hash::Util qw(lock_hash unlock_hash);
use Time::HiRes qw(time);
use DateTime;

# Do not remove the following no critic, no security or object issues possible. 
# We can use perls default behaviour on return.
##no critic qw(Subroutines::RequireFinalReturn,ControlStructures::ProhibitMutatingListFunctions);

use constant VERSION => '2.7';


our @files;
our %lists;
our %properties;
our %instructors;
our $CONSTREQ = 0;
###
# Package fields are always global in perl!
###
our %ANONS;
###
# CNF Instruction tag covered reserved words. 
# You probably don't want to use these as your own possible instruction implementation.
###
our %RESERVED_WORDS = (CONST=>1, DATA=>1,   FILE=>1, TABLE=>1,  TREE=>1,
                       INDEX=>1, VIEW=>1,   SQL=>1,  MIGRATE=>1, 
                       DO=>1,    PLUGIN=>1, MACRO=>1,'%LOG'=>1, INCLUDE=>1, INSTRUCTOR=>1);
sub isReservedWord {my ($self, $word)=@_; return $RESERVED_WORDS{$word}}
###

###
# Create a new CNFParser instance.
# $path - Path to some .cnf file, to parse, not compsuluory to add now.
# $attrs - is reference to hash of constances and settings to dynamically employ.
# $del_keys -  is a reference to an array of constance attributes to dynamically remove. 
sub new { my ($class, $path, $attrs, $del_keys, $self) = @_; 
    if ($attrs){
        $self = \%$attrs;        
    }else{
        $self = {   #Case Sensitive don't tell me you set Do_enabled and it ain't working?
                    DO_enabled      =>0, # Enable/Disable DO instruction. Which could evaluated potentially be an doom execute destruction.
                    ANONS_ARE_PUBLIC=>1, # Anon's are shared and global for all of instances of this object, by default.
                    ENABLE_WARNINGS =>1, # Disable this one, and you will stare into the void, on errors or operations skipped.
                    STRICT          =>1, # Enable/Disable strict processing to FATAL on errors, this throws and halts parsing on errors.
                    DEBUG           =>0  # Not internally used by the parser, but possible a convience bypass setting for code using it.
        }; 
    }
    $CONSTREQ = $self->{'CONSTANT_REQUIRED'};
    if (!$self->{'ANONS_ARE_PUBLIC'}){ #Not public, means are private to this object, that is, anons are not static.
         $self->{'ANONS_ARE_PUBLIC'} = 0; #<- Caveat of Perl, if this is not set to zero, it can't be accessed legally in a protected hash.
         $self->{'__ANONS__'} = {};
    }
    $self->{'__DATA__'}  = {};
    if(exists $self->{'%LOG'}){
        if(ref($self->{'%LOG'}) ne 'HASH'){
            die '%LOG'. "passed attribute is not an hash reference."
        }else{
            $properties{'%LOG'} = $self->{'%LOG'}
        }
    }
    $self->{'STRICT'} = 1  if not exists $self->{'STRICT'}; #make strict by default if missing.    
    bless $self, $class; $self->parse($path, undef, $del_keys) if($path);
    return $self;
}
#

sub import {     
    my $caller = caller;    
    {
         *{"${caller}::configDumpENV"} = \&dumpENV;
         *{"${caller}::anon"} = \&anon;
         *{"${caller}::SQL"} = \&SQL;
    }
    return 1;    
}

###
# Post parsing instructed special item objects.
##
package InstructedDataItem {
    
    our $dataItemCounter = int(0);

    sub new { my ($class, $ele, $ins, $val) = @_;
        bless {
                ele => $ele,
                aid => $dataItemCounter++,
                ins => $ins,
                val => $val
        }, $class    
    }
    sub toString {
        my $self = shift;
        return "<<".$self->{ele}."<".$self->{ins}.">".$self->{val}.">>"
    }
}
#

###
# PropertyValueStyle objects must have same rule of how an property body can be scripted for attributes.
##
package PropertyValueStyle {    
    sub new {
        my ($class, $element, $script, $self) =  @_;
        $self = {} if not $self;
        $self->{element}=$element;
        if($script){
            my ($p,$v);                     
            foreach my $itm($script=~/\s*(\w*)\s*[:=]\s*(.*)\s*/gm){
                if($itm){
                    if(!$p){
                        $p = $itm;
                    }else{
                        $self->{$p}=$itm;
                        undef $p;
                    }
                }                
            }
        }else{
            warn "PropertyValue process what?"
        }
        bless $self, $class
    }
    sub result {
        my ($self, $value) =  @_;
        $self->{value} = $value;
    }
}
#

###
# The metaverse is that further this can be expanded, 
# to provide further dynamic meta processing of the property value of an anon.
# When the future becomes life in anonymity, unknown variables best describe the meta state.
##
package META_PROCESS {
    sub constance{
         my($class, $set) = @_; 
        if(!$set){
            $set =  {anonymous=>'*'}
        }
        bless $set, $class
    }
    sub process{
        my($self, $property, $val) = @_;        
        if($self->{anonymous} ne '*'){
           return  $self->{anonymous}($property,$val)
        }
        return $val;
    }
}
use constant META => META_PROCESS->constance();
use constant META_TO_JSON => META_PROCESS->constance({anonymous=>*_to_JSON});
sub _to_JSON {
my($property, $val) = @_;
return <<__JSON
{"$property"="$val"}
__JSON
}

###
# Anon properties are public variables. Constance's are protected and instance specific, both config file provided (parsed in).
# Anon properties of an config instance are global by default, means they can also be statically accessed, i.e. CNFParser::anon(NAME)
# They can be; and are only dynamically set via the config instance directly.
# That is, if it has the ANONS_ARE_PUBLIC property set, and by using the empty method of anon() with no arguments.
# i.e. ${CNFParser->new()->anon()}{'MyDynamicAnon'} = 'something';
# However a private config instance, will have its own anon's. And could be read only if it exist as a property, via this anon(NAME) method.
# This hasn't been yet fully specified in the PerlCNF specs.
# i.e. ${CNFParser->new({ANONS_ARE_PUBLIC=>0})->anon('MyDynamicAnon') # <-- Will not be available.  
##
sub anon {  my ($self, $n, $args)=@_;
    my $anechoic = \%ANONS;
    if(ref($self) ne 'CNFParser'){
        $n = $self;
    }elsif (not $self->{'ANONS_ARE_PUBLIC'}){            
        $anechoic = $self->{'__ANONS__'};        
    }
    if($n){
        my $ret = %$anechoic{$n};
        return if !$ret;
        if($args){
            my $ref = ref($args);
            if($ref eq 'META_PROCESS'){
                my @arr = ($ret =~ m/(\$\$\$.+?\$\$\$)/gm);
                foreach my $find(@arr) {# <- MACRO TAG translate. ->
                        my $s= $find; $s =~ s/^\$\$\$|\$\$\$$//g;# 
                        my $r = %$anechoic{$s};
                        if(!$r && exists $self->{$s}){#fallback to maybe constant property has been seek'd?
                            $r = $self->{$s};
                        }
                        if(!$r){
                            warn "Unable to find property to translate macro expansion: $n -> $find\n" 
                                 unless $self and not $self->{ENABLE_WARNINGS}
                        }else{
                            $ret =~ s/\Q$find\E/$r/g;                    
                        }
                }
                $ret = $args->process($n,$ret);

            }elsif($ref eq 'HASHREF'){
                foreach my $key(keys %$args){                    
                    if($ret =~ m/\$\$\$$key\$\$\$/g){
                       my $val = %$args{$key};
                       $ret =~ s/\$\$\$$key\$\$\$/$val/g;
                    }                    
                }
            }elsif($ref eq 'ARRAY'){  #we rather have argument passed as an proper array then a list with perl
                my $cnt = 1;
                foreach(@$args){
                    $ret =~ s/\$\$\$$cnt\$\$\$/$_/g;
                    $cnt++;
                }
            }else{
                my $val =  %$anechoic{$args};
                $ret =~ s/\$\$\$$args\$\$\$/$val/g;
                warn "Scalar argument passed $args, did you mean array to pass? For property $n=$ret\n" 
                                 unless $self and not $self->{ENABLE_WARNINGS}                
            }
        }        
        return $$ret if ref($ret) eq "REF";
        return $ret;
    }
    return $anechoic;
}

# Validates and returns a constant named value as part of this configs instance.
# Returns false if it doesn't exist.
sub const { my ($self,$c)=@_; 
    if(exists $self->{$c}){
       return  $self->{$c}
    }
    return;
}

##
# Collections are global, Reason for this is that any number of subsequent files parsed,
# might contain properties that overwrite previous existing ones. 
# Or require ones that don't includes, expecting thm to be there.
# This overwritting can be erronous, but also is not expected to be very common to happen.
# Following method, provides direct access to the properties, this method shouldn't be used in general.
sub collections {\%properties}

# Collection now returns the contained type dereferenced.
# Make sure you use the appropriate Perl type on the receiving end.
# Note, if properties contain any scalar key entry, it sure hasn't been set by this parser.
sub collection { my($self, $name) = @_;
    if(exists($properties{$name})){
       my $ret = $properties{$name};
       if(ref($ret) eq 'ARRAY'){ 
          return  @{$ret}
       }else{
          return  %{$ret}
       }
    }
    return %properties{$name}
}
sub data {shift->{'__DATA__'}}

sub listDelimit {                 
    my ($this, $d , $t)=@_;                 
    my @p = @{$lists{$t}};
    if(@p&&$d){                   
    my @ret = ();
    foreach (@p){
        my @s = split $d, $_;
        push @ret, @s;
    }
    $lists{$t}=\@ret;
    return @{$lists{$t}};
    }
    return;            
}
sub lists {\%lists}
sub list  {
        my $t=shift;if(@_ > 0){$t=shift;} 
        my $an = $lists{$t}; 
        return @{$an} if defined $an; 
        die "Error: List name '$t' not found!"
}

# Adds a list of environment expected list of variables.
# This is optional and ideally to be called before parse.
# Requires and array of variables to be passed.
sub addENVList { my ($self, @vars) = @_;
    if(@vars){
        foreach my $var(@vars){
            next if $self->{$var};##exists already.
            if((index $var,0)=='$'){#then constant otherwise anon
                $self->{$var} = $ENV{$var};
            }
            else{
                anon()->{$var} = $ENV{$var};
            }
        }
    }return;
}


sub template { my ($self, $property, %macros) = @_;    
    my $val = $self->anon($property);
    if($val){       
       foreach my $m(keys %macros){
           my $v = $macros{$m};
           $m ="\\\$\\\$\\\$".$m."\\\$\\\$\\\$";
           $val =~ s/$m/$v/gs;       
       }
       my $prev;
       foreach my $m(split(/\$\$\$/,$val)){
           if(!$prev){
               $prev = $m;
               next;
           }
           undef $prev;
           my $pv = $self->anon($m);
           if(!$pv && exists $self->{$m}){
               $pv =  $self->{$m}#constant($self, '$'.$m);
           }
           if($pv){
               $m = "\\\$\\\$\\\$".$m."\\\$\\\$\\\$";
               $val =~ s/$m/$pv/gs;
           }
       }
       return $val;
    }    
}
#


###
# Parses a CNF file or a text content if specified, for this configuration object.
##
sub parse {  my ($self, $cnf, $content, $del_keys) = @_;
    my @tags;
    my $DO_enabled = $self->{'DO_enabled'};
    my %instructs;
    our%includes;
    my $anons;
    if($self->{'ANONS_ARE_PUBLIC'}){  
       $anons = \%ANONS;
    }else{          
       $anons = $self->{'__ANONS__'};
    }    
    if(not $content){
        open(my $fh, "<:perlio", $cnf )  or  die "Can't open $cnf -> $!";        
        read $fh, $content, -s $fh;        
        close $fh;
        my @stat = stat($cnf);
        $self->{CNF_STAT}    = \@stat; 
        $self->{CNF_CONTENT} = $cnf;        
    }else{
        my $type =Scalar::Util::reftype($content);
        if($type && $type eq 'ARRAY'){
           $content = join  "",@$content;
           $self->{CNF_CONTENT} = 'ARRAY';
        }
    }
    $content =~ m/^\!(CNF\d+\.\d+)/;
    my $CNF_VER = $1; $CNF_VER="Undefined!" if not $CNF_VER;
    $self->{CNF_VERSION} = $CNF_VER if not defined $self->{CNF_VERSION};

    unlock_hash(%$self);# We control from here the constances, need to unlock them if previous parse was run.

    @tags =  ($content =~ m/(<<)(<*.*?>*)(>>)/gms);
    
    foreach my $tag (@tags){             
	  next if not $tag;
      next if $tag =~ m/^(>+)|^(<<)/;
      if($tag=~m/^<CONST/){#constant multiple properties.

            foreach  (split '\n', $tag) {
                my $k;                
                my @properties = map {
                    s/^\s+|\s+$//;  # strip unwanted spaces
                    s/^\s*["']|['"]\s*$//g;#strip qoutes
                    s/<CONST\s//; # strip  identifier
                    s/\s*>$//;
                    $_          # return the modified string
                }   split /\s*=\s*/, $_;                
                foreach (@properties) {
                      if ($k){
                            $self->{$k} = $_ if not $self->{$k};
                            undef $k;
                      }
                      else{
                            $k = $_;
                      }
                }
            }

        }        
        else{
            #vars are e-element,t-token or instruction,v- for value, vv -array of the lot.
            my ($e,$t,$v,@vv);
            # Before mauling into possible value types, let us go for the full expected tag specs first:
            # <<{$sig}{name}<{INSTRUCTION}>{value\n...value\n}>>
            # Found in -> <https://github.com/wbudic/PerlCNF//CNF_Specs.md>
            #@vv = ($tag =~ m/(@|[\$@%\W\w]*?)<(\w*)>(.*)/gsm);
            #@vv = ($tag =~ m/([@%\w\$]*|\w*?)[<>]([@%\w\s\W]*)>*(.*)/gms);
            @vv = ($tag =~ m/([@%\w\$\.\/]*|\w*?)[<>]([@%\w]*)>*(.*)/gms);
            $e =$vv[0]; $t=$vv[1]; $v=$vv[2];
            if(!$RESERVED_WORDS{$t} || @vv!=3){
                if($tag =~ m/(@|[\$@%\W\w]*)<>(.*)/g){
                    $e =$1; $v=$2; $t = $v;
                    $self->warn("Encountered a mauled instruction tag: $tag\n")
                }else{# Nope!? Let's continue mauling. Life is cruel, that's for sure.
                    @vv = ($tag =~ m/(@|[\$@%\W\w]*)<([.]*\s*)>*|(.*)>+|(.*)/gsm);
                    $e = shift @vv;#$e =~ s/^\s*//g;            
                    if(!$e){
                        # From now on, parser mauls the tag before making out the value.
                        @vv = ($tag =~ m/(@|[\$@%]*\w*)(<|>)/g);
                        $e = shift @vv; 
                        $t = shift @vv;                    
                        if(!$e){
                                if($self->{ENABLE_WARNINGS}){
                                    $self->warn("Encountered invalid tag formation -> <<$tag>>");
                                }else{
                                    die  "Encountered invalid tag formation -> <<$tag>>"
                                }
                        }
                        $v = shift @vv; 
                    }else{
                        if($e=~/[@%]/){
                            $v =~ /^<(.*)>$/gms;    
                            $v = $1 if $1;                        
                        }else{
                            do{ $t = shift @vv; } while( !$t && @vv>0 ); $t =~ s/\s$//;
                                $v = shift @vv;                                           
                                if(!$v){
                                    if(@vv==0 && !$RESERVED_WORDS{$t}){#<- The instruction is assumed to hold the value if it isn't an reserved word.
                                        $v = $t
                                    }
                                    foreach(@vv){#<- Attach any valid fallback from complex rexp.
                                        $v .= $_ if $_;
                                    }
                                }
                            }                   
                    }
                }
            }else{ 
                $v =~ s/\s>$// ; #Strip if old format of instruction. Pre v.2.5.
            }
            #Do we have an autonumbered instructed list?   
            #DATA best instructions are exempted and differently handled by existing to only one uniquely named property.
            #So its name can't be autonumbered.
            if ($e =~ /(.*?)\$\$$/){    
                $e = $1;
                if($t ne 'DATA'){
                   my $array = $lists{$e};
                   if(!$array){$array=();$lists{$e} = \@{$array};}               
                   push @{$array}, InstructedDataItem -> new($e, $t, $v);
                   next
                }   
            }elsif ($e eq '@'){#collection processing.
                my $isArray = $t=~ m/^@/;
                if(!$v && $t =~ m/(.*)>(\s*.*\s*)/gms){
                    $t = $1;
                    $v = $2;
                }               
                my @lst = ($isArray?split(/[,\n]/, $v):split('\n', $v)); $_="";
                my @props = map {
                        s/^\s+|\s+$//;   # strip unwanted spaces
                        s/^\s*["']|['"]$//g;#strip quotes
                        #s/>+//;# strip dangling CNF tag
                        $_ ? $_ : undef   # return the modified string
                    } @lst;
                if($isArray){
                    if($self->isReservedWord($t)){
                        $self->warn("ERROR collection is trying to use a reserved property name -> $t.");
                        next
                    }else{
                            my @arr=(); 
                            foreach  (@props){                        
                                push @arr, $_ if($_ && length($_)>0);
                            }
                            $properties{$t}=\@arr;
                    }
                }else{
                    my %hsh;                    
                    my $macro = 0;                    
                    if(exists($properties{$t})){
                        if($self->isReservedWord($t)){
                            $self->warn("Skipped overwritting reserved property -> $t.");
                            next
                        }else{
                            %hsh =  %{$properties{$t}}
                        }
                    }else{
                       %hsh =();                      
                    }
                    foreach  my $p(@props){ 
                        if($p && $p eq 'MACRO'){$macro=1}
                        elsif( $p && length($p)>0 ){                            
                            my @pair = ($p=~/\s*(\w*)\s*[=:]\s*(.*)/s);#split(/\s*=\s*/, $p);
                            next if (@pair != 2 || $pair[0] =~ m/^[#\\\/]+/m);#skip, it is a comment or not '=' delimited line.                            
                            my $name  = $pair[0]; 
                            my $value = $pair[1]; $value =~ s/^\s*["']|['"]$//g;#strip quotes
                            if($macro){
                                my @arr = ($value =~ m/(\$\$\$.+?\$\$\$)/gm);
                                foreach my $find(@arr) {                                
                                    my $s = $find; $s =~ s/^\$\$\$|\$\$\$$//g;
                                    my $r = $anons->{$s};                                    
                                    $r = $self->{$s} if !$r;
                                    $r = $instructs{$s} if !$r;
                                    CNFParserException->throw(error=>"Unable to find property for $t.$name -> $find\n",show_trace=>1) if !$r;
                                    $value =~ s/\Q$find\E/$r/g;                    
                                }
                            }
                            $hsh{$name}=$value;  $self->log("macro $t.$name->$value\n") if $self->{DEBUG}
                        }
                    }
                    $properties{$t}=\%hsh;
                }
                next;
            }              

            if($t eq 'CONST'){#Single constant with mulit-line value;

               $v =~ s/^\s//;
               #print "[[$t]]=>{$v}\n";
               $self->{$e} = $v if not $self->{$e}; # Not allowed to overwrite constant.
               
            }elsif($t eq 'DATA'){
               $v=~ s/^\n//; 
               foreach(split /~\n/,$v){
                   my @a;
                   $_ =~ s/\\`/\\f/g;#We escape to form feed  the found 'escaped' backtick so can be used as text.
                   foreach my $d (split /`/, $_){
                        $d =~ s/\\f/`/g; #escape back form feed to backtick.
                        $d =~ s/~$//; #strip dangling ~ if there was no \n
                        $t = substr $d, 0, 1;
                        if($t eq '$'){
                            $v =  $d;            #capture specked value.
                            $d =~ s/\$$|\s*$//g; #trim any space and system or constant '$' end marker.
                            if($v=~m/\$$/){
                                $v = $self->{$d}; $v="" if not $v;
                            }
                            else{
                                $v = $d;
                            }
                            push @a, $v;
                        }
                        else{                            
                            if($t =~ /^\#(.*)/) {#First is usually ID a number and also '#' signifies number.
                                $d = $1;#substr $d, 1;
                                $d=0 if !$d; #default to 0 if not specified.
                                push @a, $d
                            }
                            else{
                              push @a, $d;
                            }
                        }
                   }                   
                   
                   my $existing = $self->{'__DATA__'}{$e};
                   if(defined $existing){
                        my @rows = @$existing;
                        push @rows, [@a] if scalar @a >0; 
                        $self->{'__DATA__'}{$e} = \@rows
                   }else{
                        my @rows; push @rows, [@a];   
                       $self->{'__DATA__'}{$e} = \@rows if scalar @a >0;   
                   }
               }           
                
            }elsif($t eq 'FILE'){
                my ($i,$path) = $cnf;
                $v=~s/\s+//g;
                $path = substr($path, 0, rindex($cnf,'/')) .'/'.$v;
                push @files, $path;
                next if !$self->{'$AUTOLOAD_DATA_FILES'};
                open(my $fh, "<:perlio", $path ) or  CNFParserException->throw("Can't open $path -> $!");
                   read $fh, $content, -s $fh;
                close   $fh;
                my @tags = ($content =~ m/<<(\w*<(.*?).*?>>)/gs);
                foreach my $tag (@tags){
                    next if not $tag;
                    my @kv = split /</,$tag;
                    $e = $kv[0];
                    $t = $kv[1];
                    $i = index $t, "\n";
                    if($i==-1){
                        $t = $v = substr $t, 0, (rindex $t, ">>");
                    }
                    else{
                        $v = substr $t, $i+1, (rindex $t, ">>")-($i+1);
                        $t = substr $t, 0, $i;
                    }
                    if($t eq 'DATA'){
                        foreach(split /~\n/,$v){
                            my @a;
                            $_ =~ s/\\`/\\f/g;#We escape to form feed  the found 'escaped' backtick so can be used as text.
                            foreach my $d (split(/`/, $_)){
                                $d =~ s/\\f/`/g; #escape back form feed to backtick.
                                $t = substr $d, 0, 1;
                                if($t eq '$'){
                                    $v =  $d;            #capture spected value.
                                    $d =~ s/\$$|\s*$//g; #trim any space and system or constant '$' end marker.
                                    if($v=~m/\$$/){
                                        $v = $self->{$d}; $v="" if not $v;
                                    }
                                    else{
                                        $v = $d;
                                    }
                                    push @a, $v;
                                }
                                else{
                                    if($t =~ /^\#(.*)/) {#First is usually ID a number and also '#' signifies number.
                                        $d = $1;#substr $d, 1;
                                        $d=0 if !$d; #default to 0 if not specified.
                                        push @a, $d
                                    }
                                    else{
                                    push @a, $d; 
                                    }                                                
                                }                                
                                my $existing = $self->{'__DATA__'}{$e};
                                if(defined $existing){
                                        my @rows = @$existing;
                                        push @rows, [@a] if scalar @a >0; 
                                        $self->{'__DATA__'}{$e} = \@rows
                                }else{
                                        my @rows; push @rows, [@a];   
                                        $self->{'__DATA__'}{$e} = \@rows if scalar @a >0;   
                                }
                            }   
                        }
                    }       
                }              
            }elsif($t eq 'INCLUDE'){
                   $includes{$e} = {loaded=>0,path=>$e,v=>$v};
            }elsif($t eq 'TREE'){
               my  $tree = CNFNode->new({'_'=>$e,script=>$v}); 
                   $tree->{DEBUG} = $self->{DEBUG};
                   $instructs{$e} = $tree; 

            }elsif($t eq 'TABLE'){         # This has now be late bound and send to the CNFSQL package. since v.2.6
               SQL()->createTable($e,$v) }  # It is hardly been used. But in future itt might change.
                elsif($t eq 'INDEX'){ SQL()->createIndex($v)}  
                   elsif($t eq 'VIEW'){ SQL()->createView($e,$v)}
                      elsif($t eq 'SQL'){ SQL($e,$v)}
                         elsif($t eq 'MIGRATE'){SQL()->migrate($e, $v)
            }
            elsif($t eq 'DO'){
                if($DO_enabled){
                    ## no critic BuiltinFunctions::ProhibitStringyEval
                    $v = eval $v;
                    ## use critic
                    chomp $v; $anons->{$e} = $v;
                }else{
                    $self->warn("Do_enabled is set to false to process property: $e\n")
                }
            }
            elsif($t eq 'PLUGIN'){ 
                if($DO_enabled){
                    $instructs{$e} = InstructedDataItem -> new($e, 'PLUGIN', $v);                    
                }else{
                    $self->warn("Do_enabled is set to false to process following plugin: $e\n")
                }                
            }
            elsif($t eq 'INSTRUCTOR'){ 
                if(not $self->registerInstructor($e, $v) && $self->{STRICT}){
                   CNFParserException->throw("Instruction Registration Failed for '<<$e<$t>$v>>'!\t");
                }
            }
            elsif(exists $instructors{$t}){
                if(not $instructors{$t}->instruct($e, $v) && $self->{STRICT}){
                   CNFParserException->throw("Instruction processing failed for '<<$e<$t>>'!\t");
                }
            }
            elsif($t eq 'MACRO'){                  
                  $instructs{$e}=$v;                  
            }
            else{
                #Register application statement as either an anonymous one. Or since v.1.2 an listing type tag.                 
                if($e !~ /\$\$$/){ #<- It is not matching {name}$$ here.
                   $v = $t if not $v; 
                    if($e=~/^\$/){
                        $self->{$e} = $v if !$self->{$e}; # Not allowed to overwrite constant.
                    }else{                        
                        $anons->{$e} = $v
                    }
                }
                else{
                    $e = substr $e, 0, (rindex $e, '$$');
                    # Following is confusing as hell. We look to store in the hash an array reference.
                    # But must convert back and fort via an scalar, since actual arrays returned from an hash are references in perl.
                    my $array = $lists{$e};
                    if(!$array){$array=();$lists{$e} = \@{$array};}
                    push @{$array}, $v;
                }            
            }            
        }
	}
    #Do smart instructions and property linking.
    if(%instructs){ 
        my @ditms;
        foreach my $e(keys %instructs){
            my $struct = $instructs{$e};
            my $type =  ref($struct);
           if($type eq 'String'){
                my $v = $struct;
                my @arr = ($v =~ m/(\$\$\$.+?\$\$\$)/gm);
                foreach my $find(@arr) {# <- MACRO TAG translate. ->
                        my $s= $find; $s =~ s/^\$\$\$|\$\$\$$//g;# 
                        my $r = %$anons{$s};
                        $r = $self->{$s} if !$r;                    
                        if(!$r){
                            $self->warn("Unable to find property to translate macro expansion: $e -> $find\n");
                        }else{
                            $v =~ s/\Q$find\E/$r/g;                    
                        }
                }            
                $anons->{$e}=$v;
            }else{ 
                $ditms[@ditms] = $struct;
            }
        }
        for my $idx(0..$#ditms) {
            my $struct = $ditms[$idx];
            my $type =  ref($struct); 
            if($type eq 'CNFNode' && $struct->{'script'}=~/_HAS_PROCESSING_PRIORITY_/si){ 
               $struct->validate($struct->{'script'}) if $self->{ENABLE_WARNINGS};
               $anons->{$struct->{'_'}} = $struct->process($self, $struct->{'script'});
               splice @ditms, $idx,1;
            }
        }
        for my $idx(0..$#ditms) {
            my $struct = $ditms[$idx];
            my $type =  ref($struct); 
            if($type eq 'CNFNode'){   
               $struct->validate($struct->{'script'}) if $self->{ENABLE_WARNINGS};            
               $anons->{$struct->{'_'}} = $struct->process($self, $struct->{'script'});
               splice @ditms, $idx,1;
            }
        }
        @ditms =  sort {$a->{aid} <=> $b->{aid}} @ditms;
        foreach my $struct(@ditms){
            my $type =  ref($struct); 
            if($type eq 'InstructedDataItem'){
                my $t = $struct->{ins};
                if($t eq 'PLUGIN'){  #for now we keep the plugin instance.
                   try{             
                            $properties{$struct->{'ele'}} = doPlugin($self, $struct, $anons);
                            $self->log("Plugin instructed ->". $struct->{'ele'});
                   }catch{ 
                            if($self->{STRICT}){
                               CNFParserException->throw(error=>@_,trace=>1);
                            }else{
                               $self->trace("Error @ Plugin -> ". $struct->toString() ." Error-> $@")                                 
                            }
                   }
                }
            }
        }
        undef %instructs;        
    }
    #Do scripted includes.
    my @inc = sort values %includes;    
    $includes{$0} = {loaded=>1,path=>$self->{CNF_CONTENT}}; #<- to prevent circular includes.
    foreach my $file(@inc){
        if(!$file->{loaded} && $file->{path} ne $self->{CNF_CONTENT}){
           if(open(my $fh, "<:perlio", $file->{path} )){
                read $fh, $content, -s $fh;
              close   $fh;              
              if($content){
                 $file->{loaded} = 1;
                 $self->parse(undef, $content)
              }else{
                 $self->error("Include content is blank for -> ".$file->{path})
              }              
            }else{
                 CNFParserException->throw("Can't open ".$file->{path}." -> $!") if $self->{STRICT};
                 $file->{loaded} = 1;
                 $self->error("Include not available -> ".$file->{path})
            }
        }
    }    
    foreach my $k(@$del_keys){        
        delete $self->{$k} if exists $self->{$k}
    }
    lock_hash(%$self);#Make repository finally immutable.
}
#

our $SQL;
sub  SQL {
    if(!$SQL){##It is late compiled on demand.
        require CNFSQL; $SQL  = CNFSQL->new();
    }
    $SQL->addStatement(@_) if @_;
    return $SQL;
}


###
# Register Instructor on tag and value for to be externally processed.
# $package  - Is the anonymouse package name.
# $body     - Contains attribute(s) linking to method(s) to be registered.
# @TODO Current Under development.
###
sub registerInstructor { 
     my ($self, $package, $body) = @_;
     $body =~ s/^\s*|\s*$//g;
     my ($obj, %args, $ins);
     foreach my $ln(split(/\n/,$body)){
             my @pair = $ln =~ /\s*(\w+)[:=](.*)\s*/;
             my $ins  = $1; $ins = $ln if !$ins;
             my $mth  = $2;
             if($ins =~ /[a-z]/){
                $args{$ins} = $mth;
                next
             }             
             if(exists $instructors{$ins}){
                $self -> error("$package<$ins> <- Instruction has been previously registered by: ".ref(${$instructors{$ins}}));
                return;
             }else{
                foreach(values %instructors){
                    if(ref($$_) eq $package){
                       $obj = $_; last
                    }
                }
                if(!$obj){
                    ## no critic (RequireBarewordIncludes)
                    require $package.'.pm';
                    my $methods =   Class::Inspector->methods($package, 'full', 'public');
                    my ($has_new,$has_instruct);
                    foreach(@$methods){
                        $has_new      = 1 if $_ eq "$package\::new";
                        $has_instruct = 1 if $_ eq "$package\::instruct";
                    }
                    if(!$has_new){
                        $self -> log("ERR $package<$ins> -> new() method not found for package.");
                        return;
                    }
                    if(!$has_instruct){
                        $self -> log("ERR $package<$ins> -> instruct() required method not found for package.");
                        return;
                    }                
                    $obj = $package -> new(\%args);
                }
                $instructors{$ins} = \$obj;
             }
     }
     return \$obj;
}

###
# Setup and pass to pluging CNF functionality.
# @TODO Current Under development.
###
sub doPlugin{
    my ($self, $struct, $anons) = @_;
    my ($elem, $script) = ($struct->{'ele'}, $struct->{'val'});
    my $plugin = PropertyValueStyle->new($elem, $script);
    my $pck = $plugin->{package};
    my $prp = $plugin->{property};
    my $sub = $plugin->{subroutine};
    if($pck && $prp && $sub){        
        ## no critic (RequireBarewordIncludes)
        require "$pck.pm";
        my $obj;
        my $settings = $properties{'%Settings'};#Properties are global.
        if($settings){
           $obj = $pck->new(\%$settings);
        }else{
           $obj = $pck->new();
        }        
        my $res = $obj->$sub($self,$prp);
        if($res){            
            return $plugin;
        }else{
            die "Sorry, the PLUGIN feature has not been Implemented Yet!"
        }
    }
    else{
        die qq(Invalid plugin encountered '$elem' in "). $self->{'CNF_CONTENT'} .qq(
        Plugin must have attributes -> 'library', 'property' and 'subroutine')
    }
}

# Writes out to a handle an CNF property or this parsers constance's as default property.
# i.e. new CNFParser()->writeOut(*STDOUT);
sub writeOut { my ($self, $handle, $property) = @_;      
    my $buffer;
    if(!$property){
        my @keys = sort keys %$self;        
        $buffer = "<<<CONST\n";
        my $with = 5;
        foreach (@keys){
           my $len = length($_);
           $with = $len + 1 if $len > $with
        }
        foreach my $key(@keys){
            my $spc = $with - length($key);
            my $val = $self->{$key};
            next if(ref($val) =~ /ARRAY|HASH/); #we write out only what is scriptable.
            if(!$val){
                if($key =~ /^is|^use|^bln|enabled$/i){
                   $val = 0
                }else{
                   $val = "\"\""
                }
            }
            elsif #Future versions of CNF will account also for multiline values for property attributes.
            ($val =~ /\n/){
                $val = "<#<\n$val>#>"
            }
            elsif($val !~ /^\d+/){
                $val = "\"$val\""
            }        
            $buffer .= ' 'x$spc. $key .  " = $val\n";     
        }
        $buffer .= ">>";
        return $buffer if !$handle;
        print $handle $buffer;
        return 1
    }
    my $prp = $properties{$property};
    if($prp){
        $buffer = "<<@<$property>\n";
        if(ref $prp eq 'ARRAY') {
            my @arr = sort keys @$prp; my $n=0;
            foreach (@arr){                
                $buffer .= "\"$_\"";
                if($arr[-1] ne $_){
                   if($n++>5){
                    $buffer .= "\n"; $n=0
                   }else{
                    $buffer .= ","
                   }
                }
            }   
        }elsif(ref $prp eq 'HASH') {
            my %hsh = %$prp;
            my @keys = sort keys %hsh;
            foreach my $key(@keys){                
                $buffer .= $key . "\t= \"". $hsh{$key} ."\"\n";     
            }
        }
        $buffer .= ">>\n";
        return $buffer if !$handle;
        print $handle $buffer;
        return 1;
    }
    else{
      $prp = $ANONS{$property};
      $prp = $self->{$property} if !$prp;
      if (!$prp){
         $buffer = "<<ERROR<$property>Property not found!>>>\n" 
      }else{
        $buffer = "<<$property><$prp>>\n";
      }
      return $buffer if !$handle;
      print $handle $buffer;      
      return 0;
    }
}

###
# The following is a typical example of an log settings property.
#
# <<@<%LOG>
#             file      = web_server.log
#             # Should it mirror to console too?
#             console   = 1
#             # Disable/enable output to file at all?
#             enabled   = 0
#             # Tail size cut, set to 0 if no tail cutting is desired.
#             tail      = 1000
# >>
###
sub log {
    my $self    = shift;
	my $message = shift;
    my $attach  = join @_; $message .= $attach if $attach;
    my %log = $self -> collection('%LOG');    
    my $time = DateTime->from_epoch( epoch => time )->strftime('%Y-%m-%d %H:%M:%S.%3N');   
    if($message =~ /^ERROR/){
        warn  $time . " " . $message;
    }
    elsif(%log && $log{console}){
        print $time . " " . $message ."\n"
    }
    if(%log && $log{enabled} && $message){
        my $logfile  = $log{file};
        my $tail_cnt = $log{tail};
        if($log{tail} && $tail_cnt && int(`tail -n $tail_cnt $logfile | wc -l`)>$tail_cnt-1){
            use File::ReadBackwards;
            my $pos = do {
               my $fh = File::ReadBackwards->new($logfile) or die $!;
               $fh->readline() for 1..$tail_cnt;
               $fh->tell()
            };            
            truncate($logfile, $pos) or die $!;
            
        }
        open (my $fh, ">>", $logfile) or die ("$!");
        print $fh $time . " - " . $message ."\n";
        close $fh;
    }
}
sub error {
    my $self    = shift;
	my $message = shift;    
    $self->log("ERROR $message");
}
use Carp qw(cluck); #what the? I know...
sub warn {
    my $self    = shift;
	my $message = shift; 
    my $time = DateTime->from_epoch( epoch => time )->strftime('%Y-%m-%d %H:%M:%S.%3N');   
    $message = "$time WARNG $message\t".$self->{CNF_CONTENT};
    if($self->{ENABLE_WARNINGS}){
        $self -> log($message)
    }else{
        cluck $message
    }
}
sub trace {
    my $self    = shift;
	my $message = shift; 
    my %log = $self -> collection('%LOG');
    if(%log){
        $self -> log($message)
    }else{
        cluck $message
    }
}

sub dumpENV{
    foreach (keys(%ENV)){print $_,"=", "\'".$ENV{$_}."\'", "\n"}
}


sub END {
undef %ANONS;
undef @files;
}
1;

__END__
## Instructions & Reserved words

   1. Reserved words relate to instructions, that are specially treated, and interpreted by the parser to perform extra or specifically processing on the current value.
   2. Reserved instructions can't be used for future custom ones, and also not recommended tag or property names.
   3. Current Reserved words list is.
       - CONST    - Concentrated list of constances, or individaly tagged name and its value.
       - DATA     - CNF scripted delimited data property, having uniform table data rows.       
       - FILE     - CNF scripted delimited data property is in a separate file.
       - %LOG     - Log settings property, i.e. enabled=1, console=1.
       - TABLE    - SQL related.
       - TREE     - Property is a CNFNode tree containing multiple debth nested children nodes.
       - INCLUDE  - Include properties from another file to this repository.
       - INDEX    - SQL related.
       - INSTRUCT - Provides custom new anonymous instruction.
       - VIEW     - SQL related.
       - PLUGIN   - Provides property type extension for the PerlCNF repository.
       - SQL      - SQL related.
       - MIGRATE  - SQL related.
       - MACRO
          1. Value is searched and replaced by a property value, outside the property scripted.
          2. Parsing abruptly stops if this abstract property specified is not found.
          3. Macro format specifications, have been aforementioned in this document. However make sure that your macro an constant also including the *$* signifier if desired.