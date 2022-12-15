# Main Parser for the Configuration Network File Format.
# This source file is copied and usually placed in a local directory, outside of its project.
# So not the actual or current version, might vary or be modiefied for what ever purpose in other projects.
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
package CNFParser;

use strict;use warnings;#use warnings::unused;
use Exception::Class ('CNFParserException');
use Syntax::Keyword::Try;
use Hash::Util qw(lock_hash unlock_hash);

sub import {     
    my $caller = caller;
    
    {    no strict 'refs';
         *{"${caller}::configDumpENV"} = \&dumpENV;
         *{"${caller}::anon"} = \&anon;
    }
    return 1;    
}


# Do not remove the following no critic, no security or object issues possible. 
# We can use perls default behaviour on return.
##no critic qw(Subroutines::RequireFinalReturn)


use constant VERSION => '2.6';

our %mig    = ();
our @sql    = ();
our @files  = ();
our %tables = ();
our %views  = ();
our %lists;
our %properties;
our $CONSTREQ = 0;
###
# Package fields are always global in perl!
###
our %ANONS  = ();
###
# CNF Instruction tag covered reserved words. 
# You probably don't want to use these as your own possible instruction implementation.
###
our %RESERVED_WORDS = (CONST=>1, DATA=>1,   FILE=>1, TABLE=>1, TREE=>1,
                       INDEX=>1, VIEW=>1,   SQL=>1,  MIGRATE=>1, 
                       DO=>1,    PLUGIN=>1, MACRO=>1);
###

sub new { my ($class, $path, $attrs, $del_keys, $self) = @_;
    if ($attrs){
        $self = \%$attrs;        
    }else{
        $self = {
                    DO_enabled=>0,       # Enable/Disable DO instruction. Wich could evaluated potentially an doom execute destruction.
                    ANONS_ARE_PUBLIC=>1, # Anon's are shared and global for all of instances of this object, by default.
                    ENABLE_WARNINGS=>1   # 
        }; 
    }
    $CONSTREQ = $self->{'CONSTANT_REQUIRED'};
    if (!$self->{'ANONS_ARE_PUBLIC'}){ #Not public, means are private to this object, that is, anons are not static.
         $self->{'ANONS_ARE_PUBLIC'} = 0; #<- Cavet of Perl, if this is not set to zero, it can't be accessed legally in a protected hash.
         $self->{'__ANONS__'} = {};
    }
    $self->{'__DATA__'}  = {};
    bless $self, $class; $self->parse($path, undef, $del_keys) if($path);
    return $self;
}
#

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
}
#

###
# PropertyValueStyle objects must have same rule of how an property body can be scripted for attributes.
##
package PropertValueStyle {    
    sub new {
        my ($class, $element, $script, $self) =  @_;
        $self = {} if not $self;
        $self->{element}=$element;
        if($script){
            my ($p,$v);
            #my @body = ($script=~/\s*(\w*)\s*[:=]\s*(.*)\s*/gm);            
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
# When the future becomes life in anonimity, unknow variables best describe the meta state.
##
package META_PROCESS {
    sub constance{
         my($class, $set) = @_; 
        if(!$set){
            $set =  {anonymouse=>'*'}
        }
        bless $set, $class
    }
    sub process{
        my($self, $property, $val) = @_;        
        if($self->{anonymouse} ne '*'){
           return  $self->{anonymouse}($property,$val)
        }
        return $val;
    }
}
use constant META => META_PROCESS->constance();
use constant META_TO_JSON => META_PROCESS->constance({anonymouse=>*_to_JSON});
sub _to_JSON {
my($property, $val) = @_;
return <<__JSON
{"$property"="$val"}
__JSON
}

###
# Anon properties are public variables. Constances are protected and instance specific, both config file provided (parsed in).
# Anon properties of an config instance are global by default, means they can also be statically accessed, i.e. CNFParser::anon(NAME)
# They can be; and are only dynamically set via the config instance directly.
# That is, if it has the ANONS_ARE_PUBLIC property set, and by using the empty method of anon() with no arguments.
# i.e. ${CNFParser->new()->anon()}{'MyDynamicAnon'} = 'something';
# However a private config instance, will have its own anon's. And could be read only if it exist as a property, via this anon(NAME) method.
# This hasn't been yet fully specifed in the PerlCNF specs.
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
                        if(!$r && exists $self->{$s}){#fallback to maybe constant property has been seeked?
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
        return $ret;
    }
    return $anechoic;
}

# Validates and returns the a constant value as part of this configs instance.
# Returns undef if not.
sub const { my ($self,$c)=@_; 
    if(exists $self->{$c}){
       return  $self->{$c}
    }
    return undef;
}
#@DEPRECATED Attributes are all the constants, also externally are read only from v.2.5+.
sub constant  {my ($self,$c)=@_; return $self->{$c} unless $CONSTREQ; 
               my $r=$self->{$c}; return $r if defined($r); return CNFParserException->throw("Required constants variable ' $c ' not defined in config!")}
#@DEPRECATED 
sub constants {my $s=shift;return %$s}


sub collections {\%properties}
sub collection {my($self, $prp)=@_;return %properties{$prp}}
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

our %curr_tables  = ();
our $isPostgreSQL = 0;

sub isPostgreSQL{shift; return $isPostgreSQL}# Enabled here to be called externally.
sub isReservedWord {my ($self, $word)=@_; return $RESERVED_WORDS{$word}}

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
sub parse { 

    my ($self, $cnf, $content, $del_keys) = @_;

    my @tags;
    my $DO_enabled = $self->{'DO_enabled'};
    my %instructs; 
    my $anons;    
    if($self->{'ANONS_ARE_PUBLIC'}){  
       $anons = \%ANONS;
    }else{          
       $anons = $self->{'__ANONS__'};
    }
    
    if(not $content){#open $cnf
        open(my $fh, "<:perlio", $cnf )  or  die "Can't open $cnf -> $!";
        read $fh, $content, -s $fh;
        close $fh;
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

            foreach  (split '\n', $tag){
                my $k;#place holder trick for split.
                my @properties = map {
                    s/^\s+|\s+$//;  # strip unwanted spaces
                    s/^\s*["']|['"]\s*$//g;#strip qoutes
                    s/<CONST\s//; # strip  identifier
                    s/\s*>$//;
                    $_          # return the modified string
                }   split /\s*=\s*/, $_;                
                foreach (@properties){
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
            my ($e,$t,$v,$st,@vv);
            # Before mauling into possible value types, let us go for the full expected tag specs first:
            # <<{$sig}{name}<{INSTRUCTION}>{value\n...value\n}>>
            # Found in -> <https://github.com/wbudic/PerlCNF//CNF_Specs.md>
            #@vv = ($tag =~ m/(@|[\$@%\W\w]*?)<(\w*)>(.*)/gsm);
            @vv = ($tag =~ m/([@%\w\$]*|\w*?)[<|>]([@%\w\s]*)>*(.*)/gms);
            $e =$vv[0]; $t=$vv[1]; $v=$vv[2];
            if(!$RESERVED_WORDS{$t} || @vv!=3){
                if($tag =~ m/(@|[\$@%\W\w]*)<>(.*)/g){
                    $e =$1; $v=$2; $t = $v;
                    warn "Encountered a mauled instruction tag: $tag\n" if $self->{ENABLE_WARNINGS};                
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
                                    warn "Encountered invalid tag formation -> <<$tag>>"
                                }else{
                                    die  "Encountered invalid tag formation -> <<$tag>>"
                                }
                        }
                        $v = shift @vv; 
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
                        s/^\s*["']|['"]$//g;#strip qoutes
                        s/>+//;# strip dangling CNF tag
                        $_ ? $_ : undef   # return the modified string
                    } @lst;
                if($isArray){
                    my @arr=(); 
                    foreach  (@props){                        
                        push @arr, $_ if($_ && length($_)>0);
                    }
                    $properties{$t}=\@arr;
                }else{
                    my %hsh;                    
                    my $macro = 0;
                    if(exists($properties{$t})){
                       %hsh =  %{$properties{$t}}
                    }else{
                       %hsh =();                      
                    }
                    foreach  my $p(@props){ 
                        if($p && $p eq 'MACRO'){$macro=1}
                        elsif( $p && length($p)>0 ){                            
                            my @pair = split(/\s*=\s*/, $p);
                            die "Not '=' delimited property -> $p" if scalar( @pair ) != 2;
                            my $name  = $pair[0]; $name =~ s/^\s*|\s*$//g;
                            my $value = $pair[1]; $value =~ s/^\s*["']|['"]$//g;#strip qoutes
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
                            $hsh{$name}=$value;  print "macro $t.$name->$value\n" if $self->{DEBUG}
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
                next if(!$self->{'$AUTOLOAD_DATA_FILES'});
                open(my $fh, "<:perlio", $path ) or  CNFParserException->throw("Can't open $path -> $!");
                read $fh, $content, -s $fh;
                close $fh;
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
            }elsif($t eq 'TREE'){
                $instructs{$e} = CNFNode->new({name=>$e,script=>$v}); 

            }elsif($t eq 'TABLE'){
               $st = "CREATE TABLE $e(\n$v);";
               $tables{$e} = $st;               
            }
            elsif($t eq 'INDEX'){
               $st = "CREATE INDEX $v;";
               push @sql, $st if $st;#push as application statement.
            }
            elsif($t eq 'VIEW'){
                $st = "CREATE VIEW $e AS $v;";
                $views{$e} = $st;                
            }
            elsif($t eq 'SQL'){
                $anons->{$e} = $v;
            }
            elsif($t eq 'MIGRATE'){
                my @m = $mig{$e};
                   @m = () if(!@m);
                push @m, $v;
                $mig{$e} = [@m];
            }
            elsif($t eq 'DO'){
                if($DO_enabled){
                    ## no critic BuiltinFunctions::ProhibitStringyEval
                    $v = eval $v;
                    ## use critic
                    chomp $v; $anons->{$e} = $_;
                }elsif($self->{ENABLE_WARNINGS}){
                    warn "Do_enabled is set to false to process property: $e\n" 
                }
            }
            elsif($t eq 'PLUGIN'){ 
                if($DO_enabled){
                    $instructs{$e} = InstructedDataItem -> new($e, 'PLUGIN', $v);                    
                }elsif($self->{ENABLE_WARNINGS}){
                    warn "Do_enabled is set to false to process plugin: $e\n" 
                }                
            }
            elsif($t eq 'MACRO'){                  
                  $instructs{$e}=$v;                  
            }
            else{
                #Register application statement as either an anonymouse one. Or since v.1.2 an listing type tag.                 
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
                            warn "Unable to find property to translate macro expansion: $e -> $find\n" if $self->{ENABLE_WARNINGS}
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
               $anons->{$struct->{'name'}} = $struct->process($self, $struct->{'script'}) if (!$struct->{'_'});
               splice @ditms, $idx,1;          
            }
        }

        foreach my $struct(@ditms){
            my $type =  ref($struct); 
           if($type eq 'CNFNode'){               
               $anons->{$struct->{'name'}} = $struct->process($self, $struct->{'script'}) if (!$struct->{'_'});
            }
        }
        foreach my $struct(@ditms){
            my $type =  ref($struct); 
            if($type eq 'InstructedDataItem'){
                my $t = $struct->{ins};
                if($t eq 'PLUGIN'){  #for now we keep the plugin instance.             
                   $properties{$struct->{'ele'}} = doPlugin($self, $struct, $anons);
                }
            }
        }
        undef %instructs;        
    }

    ###
    # Following is experimental. Not generally required, and it is a bit of an overkill.
    ###
    if(not $self->{'ANONS_ARE_PUBLIC'}){
        # We clone of references of global ones which are public, for availability.
        foreach(keys %ANONS){
             next if $anons->{$_};
             $anons->{$_}=\$ANONS{$_} #<- Interesting to see what happens when the global entry is changed later,
                                    #   By another loaded repository, after this one. Having different values.
        }
    }
    foreach (@$del_keys){
        my $k=$_;
        delete $self->{$k} if exists $self->{$k}
    }
    lock_hash(%$self);#Make them finally constances.
}
#

###
# Setup and pass to pluging CNF functionality.
# @TODO Current Under development.
###
sub doPlugin{
    my ($self, $struct, $anons) = @_;
    my ($elem, $script) = ($struct->{'ele'}, $struct->{'val'});
    my $plugin = PropertValueStyle->new($elem, $script);
    my $pck = $plugin->{package};
    my $prp = $plugin->{property};
    my $sub = $plugin->{subroutine};
    if($pck && $prp && $sub){        
        ## no critic (RequireBarewordIncludes)
        require "$pck.pm";
        my $obj;
        my $settings = $self->collection('%Settings');
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
        warn qq(Invalid plugin encountered '$elem' in "). $self->{'CNF_CONTENT'} .qq(
        Plugin must have attributes -> 'library', 'property' and 'subroutine')
    }
}
##
# Required to be called when using CNF with an database based storage.
# This subrotine is also a good example why using generic driver is not recomended. 
# Various SQL db server flavours meta info is def. handled differently and not updated in them.
#
sub initiDatabase { my($self, $db, $do_not_auto_synch, $st) = @_;
#Check and set CNF_CONFIG
try{    
    $isPostgreSQL = $db-> get_info( 17) eq 'PostgreSQL';
    if($isPostgreSQL){
        my @tbls = $db->tables(undef, 'public'); #<- This is the proper way, via driver, doesn't work on sqlite.
        foreach (@tbls){
            my $t = uc substr($_,7); $t =~ s/^["']|['"]$//g;
            $curr_tables{$t} = 1;
        }
    }
    else{        
        my $pst = selectRecords($self, $db, "SELECT name FROM sqlite_master WHERE type='table' or type='view';");        
        while(my @r = $pst->fetchrow_array()){
            $curr_tables{$r[0]} = 1;
        }
    }

    if(!$curr_tables{CNF_CONFIG}){        
        my $stmt;
        if($isPostgreSQL){
            $stmt = qq|
                    CREATE TABLE CNF_CONFIG
                    (
                        NAME character varying(16)  NOT NULL,
                        VALUE character varying(128) NOT NULL,
                        DESCRIPTION character varying(256),
                        CONSTRAINT CNF_CONFIG_pkey PRIMARY KEY (NAME)
                    )|;
        }else{
            $stmt = qq|
                CREATE TABLE CNF_CONFIG (
                    NAME VCHAR(16) NOT NULL,
                    VALUE VCHAR(128) NOT NULL,
                    DESCRIPTION VCHAR(256)
                )|;
        }
        $db->do($stmt);        
        print "CNFParser-> Created CNF_CONFIG table.";
        $st = $db->prepare('INSERT INTO CNF_CONFIG VALUES(?,?,?);');
        $db->begin_work();
        foreach my $key($self->constants()){
            my ($dsc,$val);
            $val = $self->constant($key);
            my @sp = split '`', $val;
            if(scalar @sp>1){$val=$sp[0];$dsc=$sp[1];}else{$dsc=""}
            $st->execute($key,$val,$dsc);
        }
        $db->commit();
    }else{
        my $sel = $db->prepare('SELECT VALUE FROM CNF_CONFIG WHERE NAME LIKE ?;');
        my $ins = $db->prepare('INSERT INTO CNF_CONFIG VALUES(?,?,?);');
        foreach my $key(sort keys %{$self->constants()}){
                my ($dsc,$val);
                $val = $self->constant($key);
                my @sp = split '`', $val;
                if(scalar @sp>1){$val=$sp[0];$dsc=$sp[1];}else{$dsc=""}
                $sel->execute($key);
                if(!$sel->fetchrow_array()){
                    $ins->execute($key,$val,$dsc);   
                }                      
        }
    }
    # By default we automatically data insert synchronize script with database state on every init. 
    # If set $do_not_auto_synch = 1 we skip that if table is present, empty or not, 
    # and if has been updated dynamically that is good, what we want. It is of external config. implementation choice.
    foreach my $tbl(keys %tables){
        if(!$curr_tables{$tbl}){
            $st = $tables{$tbl};
            print "CNFParser-> SQL: $st\n";
            $db->do($st);
            print "CNFParser-> Created table: $tbl\n";
        }
        else{
            next if $do_not_auto_synch;
        }
        if(isPostgreSQL()){
            $st = lc $tbl; #we lc, silly psql is lower casing meta and case sensitive for internal purposes.
            $st="select column_name, data_type from information_schema.columns where table_schema = 'public' and table_name = '$st';";            
            print "CNFParser-> $st", "\n";
           $st = $db->prepare($st);          
        }else{
           $st = $db->prepare("pragma table_info($tbl)");
        }
        $st->execute();  
        my $q =""; my @r;
        while(@r=$st->fetchrow_array()){ $q.="?,"; } $q =~ s/,$//;
        my $ins = $db->prepare("INSERT INTO $tbl VALUES($q);");        
        $st="SELECT * FROM $tbl where ".getPrimaryKeyColumnNameWherePart($db, $tbl); 
        print  "CNFParser-> $st\n";
        my $sel = $db->prepare($st);
        @r = @{$self->{'__DATA__'}{$tbl}};
        $db->begin_work();
          foreach my $rs(@r){
            my @cols=split(',',$rs);
            # If data entry already exists in database, we skip and don't force or implement an update, 
            # as potentially such we would be overwritting possibly changed values, and inserting same pk's is not allowed as they are unique.
            next if hasEntry($sel, $cols[0]);
            print "CNFParser-> Inserting into $tbl -> @cols\n";
            $ins->execute(@cols);
        }
        $db->commit();
    }
    foreach my $view(keys %views){
        if(!$curr_tables{$view}){
            $st = $views{$view};
            print "CNFParser-> SQL: $st\n";
            $db->do($st);
            print "CNFParser-> Created view: $view\n";
        }
    }
    # Following is not been kept no more for external use.
    undef %tables;
    undef %views;
    undef %mig;    
}
catch{
  CNFParserException->throw(error=>$@, show_trace=>1);   
}
return $self -> constant('$RELEASE_VER');
}

sub hasEntry{  my ($sel, $uid) = @_; 
    $uid=~s/^["']|['"]$//g;
    $sel->execute($uid);
    my @r=$sel->fetchrow_array();
    return scalar(@r);
}

sub getPrimaryKeyColumnNameWherePart { my ($db,$tbl) = @_; $tbl = lc $tbl;
    my $sql = $isPostgreSQL ? qq(SELECT c.column_name, c.data_type
FROM information_schema.table_constraints tc 
JOIN information_schema.constraint_column_usage AS ccu USING (constraint_schema, constraint_name) 
JOIN information_schema.columns AS c ON c.table_schema = tc.constraint_schema
  AND tc.table_name = c.table_name AND ccu.column_name = c.column_name
WHERE constraint_type = 'PRIMARY KEY' and tc.table_name = '$tbl') : 
qq(PRAGMA table_info($tbl););
my $st = $db->prepare($sql); $st->execute();
my @r  = $st->fetchrow_array();
if(!@r){
    CNFParserException->throw(error=> "Table missing or has no Primary Key -> $tbl", show_trace=>1);
}
    if($isPostgreSQL){
        return $r[0]."=?";
    }else{
        # sqlite
        # cid[0]|name|type|notnull|dflt_value|pk<--[5]
        while(!$r[5]){
            @r  = $st->fetchrow_array();
            if(!@r){
            CNFParserException->throw(error=> "Table  has no Primary Key -> $tbl", show_trace=>1);
            }
        }
        return $r[1]."=?";
    }
}

sub selectRecords {
    my ($self, $db, $sql) = @_;
    if(scalar(@_) < 2){
         die  "Wrong number of arguments, expecting CNFParser::selectRecords(\$db, \$sql) got Settings::selectRecords('@_').\n";
    }
    try{
        my $pst	= $db->prepare($sql);                
        return 0 if(!$pst);
        $pst->execute();
        return $pst;
    }catch{
                CNFParserException->throw(error=>"Database error encountered!\n ERROR->$@\n SQL-> $sql DSN:".$db, show_trace=>1);
    }
}
#@deprecated
sub tableExists { my ($self, $db, $tbl) = @_;
    try{
        $db->do("select count(*) from $tbl;");
        return 1;
     }catch{}
     return 0;
}
###
# Buffer loads initiated a file for sql data instructions.
# TODO 2020-02-13 Under development.
#
sub initLoadDataFile {# my($self, $path) = @_;
return 0;
}
###
# Reads next collection of records into buffer.
# returns 2 if reset with new load.
# returns 1 if done reading data tag value, last block.
# returns 0 if done reading file, same as last block.
# readNext is accessed in while loop,
# filling in a block of the value for a given CNF tag value.
# Calling readNext, will clear the previous block of data.
# TODO 2020-02-13 Under development.
#
sub readNext(){
return 0;
}

# Writes out to handle an property.
sub writeOut { my ($self, $handle, $property) = @_;
    my $prp = $properties{$property};
    if($prp){
        print $handle "<<@<$property><\n";
        if(ref $prp eq 'ARRAY') {
            my @arr = sort keys @$prp; my $n=0;
            foreach (@arr){                
                print $handle "\"$_\"";
                if($arr[-1] ne $_){
                   if($n++>5){print $handle "\n"; $n=0}
                   else{print $handle ",";}
                }
            }   
        }elsif(ref $prp eq 'HASH') {
            my %hsh = %$prp;
            my @keys = sort keys %hsh;
            foreach my $key(@keys){                
                print $handle $key . "\t= \"". $hsh{$key} ."\"\n";     
            }
        }
        print $handle ">>>\n";

      return 1;
    }
    else{
      $prp = $ANONS{$property};
      $prp = $self->{$property} if !$prp;
      die "Property not found -> $property" if !$prp;
      print $handle "<<$property><$prp>>\n";
      return 0;
    }
}



sub dumpENV{
    foreach (keys(%ENV)){print $_,"=", "\'".$ENV{$_}."\'", "\n"}
}

###
# Closes any buffered files and clears all data for the parser.
# TODO 2020-02-13 Under development.
#
sub END {

undef %ANONS;
undef %mig;
undef @sql;
undef @files;
undef %tables;

}

### CGI END
1;