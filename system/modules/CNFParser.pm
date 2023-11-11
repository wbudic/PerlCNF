###
# Main Parser for the Configuration Network File Format.
##
package CNFParser;

use strict;use warnings;#use warnings::unused;
use Exception::Class ('CNFParserException');
use Syntax::Keyword::Try;
use Hash::Util qw(lock_hash unlock_hash);
use File::ReadBackwards;
use File::Copy;

require CNFMeta; CNFMeta::import();
require CNFNode;
require CNFDateTime;

# Do not remove the following no critic, no security or object issues possible.
# We can use perls default behaviour on return.
##no critic qw(Subroutines::RequireFinalReturn)
##no critic Perl::Critic::Policy::ControlStructures::ProhibitMutatingListFunctions

use constant VERSION => '3.0';
our @files;
our %lists;
our %properties;
our %instructors;
our $SQL;

###
# Package fields are always global in perl!
###
our %ANONS;
#private -> Instance fields:
                my $anons;
                my @includes; my $CUR_SCRIPT;
                my %instructs;
                my $IS_IN_INCLUDE_MODE;
                my $LOG_TRIM_SUB;
###
# CNF Instruction tag covered reserved words.
# You can't use any of these as your own possible instruction implementation, unless in lower case.
###

our %RESERVED_WORDS = map +($_, 1), qw{ CONST CONSTANT DATA DATE VARIABLE VAR
                                        FILE TABLE TREE INDEX
                                        VIEW SQL MIGRATE DO LIB PROCESSOR
                                        PLUGIN MACRO %LOG INCLUDE INSTRUCTOR };

sub isReservedWord    { my ($self, $word)=@_; return $word ? $RESERVED_WORDS{$word} : undef }
###

###
# Constance required setting, if set to 1, const method when called will rise exception rather then return undef.
###
our $CONSTREQ = 0;

###
# Create a new CNFParser instance.
# $path - Path to some .cnf_file file, to parse, not compsuluory to add now? Make undef.
# $attrs - is reference to hash of constances and settings to dynamically employ.
# $del_keys -  is a reference to an array of constance attributes to dynamically remove.
sub new { my ($class, $path, $attrs, $del_keys, $self) = @_;
    if ($attrs){
        $self = \%$attrs;
    }else{
        $self = {
                  DO_ENABLED      => 0,  # Enable/Disable DO instruction. Which could evaluated potentially be an doom execute destruction.
                  ANONS_ARE_PUBLIC=> 1,  # Anon's are shared and global for all of instances of this object, by default.
                  ENABLE_WARNINGS => 1,  # Disable this one, and you will stare into the void, about errors or operations skipped.
                  STRICT          => 1,  # Enable/Disable strict processing to FATAL on errors, this throws and halts parsing on errors.
                  HAS_EXTENSIONS  => 0,  # Enable/Disable extension of custom instructions. These is disabled by default and ingored.
                  DEBUG           => 0,  # Not internally used by the parser, but possible a convienince bypass setting for code using it.
                  CNF_CONTENT     => "", # Origin of the script, this will be set by the parser, usually the path of a script file or is direct content.
                  RUN_PROCESSORS  => 1,  # When enabled post parse processors are run, are these outside of the scope of the parsers executions.
        };
    }
    $CONSTREQ = $self->{CONSTANT_REQUIRED};
    if (!$self->{ANONS_ARE_PUBLIC}){ #Not public, means are private to this object, that is, anons are not static.
         $self->{ANONS_ARE_PUBLIC} = 0; #<- Caveat of Perl, if this is not set to zero, it can't be accessed legally in a protected hash.
         $self->{__ANONS__} = {};
    }
    if(exists  $self->{'%LOG'}){
        if(ref($self->{'%LOG'}) ne 'HASH'){
            die '%LOG'. "passed attribute is not an hash reference."
        }else{
            $properties{'%LOG'} = $self->{'%LOG'}
        }
    }
    $self->{STRICT}          = 1 if not exists $self->{STRICT}; #make strict by default if missing.
    $self->{ENABLE_WARNINGS} = 1 if not exists $self->{ENABLE_WARNINGS};
    $self->{HAS_EXTENSIONS}  = 0 if not exists $self->{HAS_EXTENSIONS};
    $self->{RUN_PROCESSORS}  = 1 if not exists $self->{RUN_PROCESSORS}; #By default enabled, disable during script dev.
    # Autoload  the data type properties placed in a separate file, from a FILE instruction.
    $self->{AUTOLOAD_DATA_FILES} =1 if not exists $self->{AUTOLOAD_DATA_FILES};
    $self->{CNF_VERSION}     = VERSION;
    $self->{__DATA__}        = {};
    undef $SQL;
    bless $self, $class; $self -> parse($path, undef, $del_keys) if($path);
    return $self;
}
#

sub import {
    my $caller = caller;    no strict "refs";
    {
        *{"${caller}::configDumpENV"}  = \&dumpENV;
        *{"${caller}::anon"}           = \&anon;
        *{"${caller}::SQL"}            = \&SQL;
        *{"${caller}::isCNFTrue"}      = \&_isTrue;
        *{"${caller}::now"}            = \&now;
    }
    return 1;
}

our $meta_has_priority  = meta_has_priority();
our $meta_priority      = meta_priority();
our $meta_on_demand     = meta_on_demand();
our $meta_process_last  = meta_process_last();
our $meta_const         = meta_const();


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
# Check a value if it is CNFPerl boolean true.
# For isFalse just negate check with not, as undef is concidered false or 0.
##
sub _isTrue{
    my $value = shift;
    return 0 if(not $value);
    return ($value =~ /1|true|yes|on|t|da/i)
}
###
# Post parsing instructed special item objects. They have lower priority to Order of apperance and from CNFNodes.
##
package InstructedDataItem {

    our $dataItemCounter   = int(0);

    sub new { my ($class, $ele, $ins, $val) = @_;
        my $priority = ($val =~ s/$meta_has_priority/""/sexi)?2:3; $val =~ s/$meta_priority/""/sexi;
           $priority = $2 if $2;
        bless {
                ele => $ele,
                aid => $dataItemCounter++,
                ins => $ins,
                val => $val,
                '^' => $priority
        }, $class
    }
    sub toString {
        my $self = shift;
        return "<<".$self->{ele}."<".$self->{ins}.">".$self->{val}.">>"
    }
}
#

###
# PropertyValueStyle objects must have same rule of how a property body can be scripted for attributes.
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
                        $itm =~ s/^\s*(['"])(.*)\g{1}$/$2/g if $itm;
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
    sub setPlugin{
        my ($self, $obj) =  @_;
        $self->{plugin} = $obj;
    }
    sub result {
        my ($self, $value) =  @_;
        $self->{value} = $value;
    }
}
#

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
        my $ref = ref($ret);
        return $$ret if $ref eq "REF";
        return $ret->val() if $ref eq "CNFNode";
        return $ret;
    }
    return $anechoic;
}

###
# Validates and returns a constant named value as part of this configs instance.
# Returns undef if it doesn't exist, and exception if constance required is set;
sub const { my ($self,$c)=@_;
    return  $self->{$c} if exists $self->{$c};
    if ($CONSTREQ){CNFParserException->throw("Required constants variable ' $c ' not defined in config!")}
    # Let's try to resolve. As old convention makes constances have a '$' prefix all upprercase.
    $c = '$'.$c;
    return  $self->{$c} if exists $self->{$c};
    return;
}

###
# Collections are global, Reason for this is that any number of subsequent files parsed,
# might contain properties that overwrite previous existing ones.
# Or require ones that don't include, and expecting them to be there.
# This overwritting can be erronous, but also is not expected to be very common to happen.
# Following method, provides direct access to the properties, this method shouldn't be used in general.
sub collections {\%properties}

#@Deprecated use property subroutine instead.
sub collection {
return property(@_);
}
###
# Collection now returns the contained type dereferenced and is concidered a property.
# Make sure you use the appropriate Perl type on the receiving end.
# Note, if properties contain any scalar key row, it sure hasn't been set by this parser.
#
sub property { my($self, $name) = @_;
    if(exists($properties{$name})){
       my $ret = $properties{$name};
       my $ref = ref($ret);
       if($ref eq 'ARRAY'){
          return  @{$ret}
       }elsif($ref eq 'PropertyValueStyle'){
          return $ret;
       }
       else{
          return  %{$ret}
       }
    }
    return %properties{$name}
}

sub data {return shift->{'__DATA__'}}

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

###
# Perform a macro replacement on tagged strings in a property value.
##
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

#private to parser sub.
sub doInstruction { my ($self,$e,$t,$v) = @_;
    my $DO_ENABLED = $self->{'DO_ENABLED'};  my $priority = 0;
    $t = "" if not defined $t;
    if($t eq 'CONST' or $t eq 'CONSTANT'){#Single constant with mulit-line value;
        # It is NOT allowed to overwrite constant.
        if (not $self->{$e}){
            $v =~ s/^\s//;
            $self->{$e} = $v;
        }else{
            warn "Skipped constant detected assignment for '$e'.";
        }
    }
    elsif($t eq 'VAR' or $t eq 'VARIABLE'){
        $v =~ s/^\s//;
        $anons->{$e} = $v;
    }
    elsif($t eq 'DATA'){
          $self->doDataInstruction_($e,$v)
    }elsif($t eq 'DATE'){
        if($v && $v !~ /now|today/i){
           $v =~ s/^\s//;
           if($self->{STRICT}&&$v!~/^\d\d\d\d-\d\d-\d\d/){
              $self-> warn("Invalid date format: $v expecting -> YYYY-MM-DD at start as possibility of  DD-MM-YYYY or MM-DD-YYYY is ambiguous.")
           }
           $v = CNFDateTime::_toCNFDate($v,$self->{'TZ'});

        }else{
           $v = CNFDateTime->new({TZ=>$self->{'TZ'}});
        }
       $anons->{$e} = $v;
    }elsif($t eq 'FILE'){#@TODO Test case this
        $self->doLoadDataFile($e,$v);
    }elsif($t eq 'INCLUDE'){
        if (!$v){
            $v=$e
        }else{
            $anons = $v;
        }
        my $prc_last  = ($v =~ s/($meta_process_last)/""/ei)?1:0;
        if (includeContains($v)){
            $self->warn("Skipping adding include $e, path already is registered for inclusion -> $v");
            return;
        }
        $includes[@includes] = {script=>$v,local=>$CUR_SCRIPT,loaded=>0, prc_last=>$prc_last};
    }elsif($t eq 'TREE'){
        my  $tree = 0;
        if (!$v){
                $v = $e;
                $e = 'LAST_DO';
        }
        if( $v =~ s/($meta_has_priority)/""/ei ){
            $priority = 1;
        }
        if( $v =~ s/$meta_priority/""/sexi ){
            $priority = $2;
        }
            $tree = CNFNode->new({'_'=>$e,'~'=>$v,'^'=>$priority});
            $tree->{DEBUG} = 1 if $self->{DEBUG};
            $instructs{$e} = $tree;
    }elsif($t eq 'TABLE'){           # This all have now be late bound and send via the CNFSQL package. since v.2.6
                                     # It is hardly been used. But in the future this might change.
        my $type = "NONE"; if ($v =~ 'AUTOINCREMENT'){$type = "AUTOINCREMENT"}
        $self->SQL()->createTable($e,$v,$type) }
        elsif($t eq 'INDEX'){ $self->SQL()->createIndex($v)}
            elsif($t eq 'VIEW'){ SQL()->createView($e,$v)}
                elsif($t eq 'SQL'){ $self->SQL($e,$v)}
                    elsif($t eq 'MIGRATE'){$self->SQL()->migrate($e, $v)
    }
    elsif($t eq 'DO'){
        if($DO_ENABLED){
            my $ret;
            if (!$v){
                 $v = $e;
                 $e = 'LAST_DO';
            }
            if( $v =~ s/($meta_has_priority)/""/ei ){
                $priority = 1;
            }
            if( $v =~ s/($meta_priority)/""/sexi ){
                $priority = $2;
            }
            if( $v=~ s/($meta_on_demand)/""/ei ){
               $anons->{$e} = CNFNode -> new({'_'=>$e,'&'=>$v,'^'=>$priority});
               return;
            }
            ## no critic BuiltinFunctions::ProhibitStringyEval
               $ret = eval $v if not $ret;
            ## use critic
             if ($ret){
                 chomp $ret;
                 $anons->{$e} = $ret;
             }else{
                 $self->warn("Perl DO_ENABLED script evaluation failed to evalute: $e Error: $@");
                 $anons->{$e} = '<<ERROR>>';
             }
        }else{
            $self->warn("DO_ENABLED is set to false to process property: $e\n")
        }
    }elsif($t eq 'LIB'){
        if($DO_ENABLED){
            if (!$v){
                 $v = $e;
                 $e = 'LAST_LIB';
            }
            try{
                use Module::Load;
                autoload $v;
                $v =~ s/^(.*\/)*|(\..*)$//g;
                $anons->{$e} = $v;
            }catch{
                    $self->warn("Module DO_ENABLED library failed to load: $v\n");
                    $anons->{$e} = '<<ERROR>>';
            }
        }else{
            $self->warn("DO_ENABLED is set to false to process a LIB property: $e\n");
            $anons->{$e} = '<<ERROR>>';
        }
    }
    elsif($t eq 'PLUGIN'){
        if($DO_ENABLED){
            $instructs{$e} = InstructedDataItem -> new($e, 'PLUGIN', $v);
        }else{
            $self->warn("DO_ENABLED is set to false to process following plugin: $e\n")
        }
    }
    elsif($t eq 'PROCESSOR'){
        if(not $self->registerProcessor($e, $v)){
            CNFParserException->throw("PostParseProcessor Registration Failed for '<<$e<$t>$v>>'!\t");
        }
    }
    elsif($t eq 'INSTRUCTOR'){
        if(not $self->registerInstructor($e, $v) && $self->{STRICT}){
            CNFParserException->throw("Instruction Registration Failed for '<<$e<$t>$v>>'!\t");
        }
    }
    elsif($t eq 'MACRO'){
        $instructs{$e}=$v;
    }
    elsif(exists $instructors{$t}){
        if(not $instructors{$t}->instruct($e, $v) && $self->{STRICT}){
            CNFParserException->throw("Instruction processing failed for '<<$e<$t>>'!\t");
        }
    }
    else{
        #Register application statement as either an anonymous one. Or since v.1.2 a listing type tag.
        if($e !~ /\$\$$/){ #<- It is not matching {name}$$ here.
            if($self->{'HAS_EXTENSIONS'}){
                $anons->{$e} = InstructedDataItem->new($e,$t,$v)
            }else{
                $v = $t if not $v;
                if($e=~/^\$/){
                    $self->{$e}  = $v if !$self->{$e}; # Not allowed to overwrite constant.
                }else{
                    $anons->{$e} = $v
                }
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
sub doLoadDataFile { my ($self,$e,$v)=@_;
        my ($path,$cnf_file) = ("",$self->{CNF_CONTENT});
        $v=~s/\s+//g;
        if(! -e $v){
            $path = substr($path, 0, rindex($cnf_file,'/')) .'/'.$v;
        }
        foreach(@files){
            return if $_ eq $path
        }
        return if not _isTrue($self->{AUTOLOAD_DATA_FILES});
        #
        $self->loadDataFile($e,$path)
}
sub loadDataFile {  my ($self,$e,$path,$v,$i)=@_;

        open(my $fh, "<:perlio", $path ) or  CNFParserException->throw("Can't open $path -> $!");
            read $fh, my $content, -s $fh;
        close   $fh;
        #
        push @files, $path;
        my @tags = ($content =~ m/<<(\w*<(.*?).*?>>)/gs);
        foreach my $tag (@tags){
            next if not $tag;
            my @kv = split /</,$tag;
            $e = $kv[0];
            $tag = $kv[1];
            $i = index $tag, "\n";
            if($i==-1){
                $tag = $v = substr $tag, 0, (rindex $tag, ">>");
            }
            else{
                $v = substr $tag, $i+1, (rindex $tag, ">>")-($i+1);
                $tag = substr $tag, 0, $i;
            }
            if($tag eq 'DATA'){
                $self->doDataInstruction_($e,$v)
            }
        }
}
#private
sub doDataInstruction_{ my ($self,$e,$v,$t,$d)=@_;
        my $add_as_SQLTable = $v =~ s/${meta('SQL_TABLE')}/""/sexi;
        my $isPostgreSQL    = $v =~ s/${meta('SQL_PostgreSQL')}/""/sexi;
        my $isHeader        = 0;
        $v=~ s/^\s*//gm;
        foreach my $row(split(/~\s/,$v)){
            my @a;
            $row =~ s/\\`/\\f/g;#We escape to form feed  the found 'escaped' backtick so can be used as text.
            my @cols = $row =~ m/([^`]*)`{0,1}/gm;pop @cols;#<-regexp is special must pop last empty element.
            foreach my $d(@cols){
                $d =~ s/\\f/`/g; #escape back form feed to backtick.
                $d =~ s/^\s*|~$//g; #strip dangling ~ if there was no \n
                $t = substr $d, 0, 1;
                if($t eq '$'){
                    $v =  $d;            #capture specked value.
                    $d =~ s/\$$|\s*$//g; #trim any space and system or constant '$' end marker.
                    if($v=~m/\$$/){
                        $v = $self->{$d};
                    }
                    else{
                        $v = $d;
                    }
                    $v="" if not $v;
                    push @a, $v;
                }
                else{
                    if($d =~ /^\#(.*)/) {#First is usually ID a number and also '#' signifies number.
                        $d = $1;
                        $d=0 if !$d; #default to 0 if not specified.
                        push @a, $d
                    }
                    else{
                        $d="" if not $d;
                        push @a, $d;
                    }
                }
            }
            if($add_as_SQLTable){
                my ($INT,$BOOL,$TEXT,$DATE) = (meta('INT'),meta('BOOL'),meta('TEXT'),meta('DATE'));
                my $ret = CNFMeta::_metaTranslateDataHeader($isPostgreSQL,@a);
                my @hdr = @$ret;
                @a = @{$hdr[0]};
                $self->SQL()->createTable($e,${$hdr[1]},$hdr[2]);
                $add_as_SQLTable = 0;$isHeader=1;
            }

            my $existing = $self->{'__DATA__'}{$e};
            if(defined $existing){
                if($isHeader){$isHeader=0;next}
                my @rows = @$existing;
                push @rows, [@a] if scalar @a >0;
                $self->{'__DATA__'}{$e} = \@rows
            }else{
                my @rows; push @rows, [@a];
                $self->{'__DATA__'}{$e} = \@rows if scalar @a >0;
            }
        }
}

###
# Parses a CNF file or a text content if specified, for this configuration object.
##
sub parse {  my ($self, $cnf_file, $content, $del_keys) = @_;

    my @tags;
    if($self->{'ANONS_ARE_PUBLIC'}){
       $anons = \%ANONS;
    }else{
       $anons = $self->{'__ANONS__'};
    }

    # We control from here the constances, as we need to unlock them if previous parse was run.
    unlock_hash(%$self);

    if(not $content){
        open(my $fh, "<:perlio", $cnf_file )  or  die "Can't open $cnf_file -> $!";
        read $fh, $content, -s $fh;
        close $fh;
        my @stat = stat($cnf_file);
        $self->{CNF_STAT}    = \@stat;
        $self->{CNF_CONTENT} = $CUR_SCRIPT = $cnf_file;
    }else{
        my $type = Scalar::Util::reftype($content);
        if($type && $type eq 'ARRAY'){
           $content = join  "",@$content;
           $self->{CNF_CONTENT} = 'ARRAY';
        }else{
           $CUR_SCRIPT = \$content;
           $self->{CNF_CONTENT} = 'script'
        }
    }
    $content =~ m/^\!(CNF\d+\.\d+)/;
    my $CNF_VER = $1; $CNF_VER="Undefined!" if not $CNF_VER;
    $self->{CNF_VERSION} = $CNF_VER if not defined $self->{CNF_VERSION};


    my $spc =   $content =~ /\n/ ? '(<{2,3}?)(<*.*?>*)(>{2,3})' : '(<{2,3}?)(<*.*?>*?)(>{2,3})$';
    @tags   =  ($content =~ m/$spc/gms);

    foreach my $tag (@tags){
	  next if not $tag;
      next if $tag =~ m/^(>+)|^(<<)/;
      if($tag =~ m/^<(\w*)\s+(.*?)>*$/gs){ # Original fastest and early format: <<<anon value>>>
           my $t = $1;
           my $v = $2;
           if(isReservedWord($self,$t)){
              my $isVar = ($t eq 'VARIABLE' || $t eq 'VAR');
              if($t eq 'CONST' or $isVar){ #constant multiple properties.
                    foreach  my $line(split '\n', $v) {
                            $line =~ s/^\s+|\s+$//;  # strip unwanted spaces
                            $line =~ s/\s*>$//;
                            $line =~ m/([\$\w]*)(\s*=\s*)(.*)/g;
                            my $name = $1;
                               $line = $3; $line =~ s/^\s*(['"])(.*)\g{1}$/$2/ if $line;#strip quotes
                            if(defined $name){
                                if($isVar){
                                    $anons ->{$name} = $line if $line
                                }else{
                                  if($line and not $self->{$name}){# Not allowed to overwrite constant.
                                    $self->{$name} = $line;
                                  }else{
                                    my $w =  "Skipping and keeping a previously set constance -> [$name] in ". $self->{CNF_CONTENT}." the new value ";
                                       $w .= ($line eq $self->{$name})?"matches it":"dosean't match -> $line.";
                                        warn $w
                                  }
                                }
                            }
                    }
              }else{
                 doInstruction($self,$v,$t,undef);
              }
           }else{
              $v =~ s/\s*>$//;
              $anons->{$t} = $v;
           }

        }else{
            #vars are e-element,t-token or instruction,v- for value, vv -array of the lot.
            my ($e,$t,$v,@vv);

            # Check if very old format and don't parse the data for old code compatibility to (still) do it.
            # This is interesting, as a newer format file is expected to use the DATA instruction and final data specified script rules.
            if($CNF_VER eq 'CNF2.2' && $tag =~ m/(\w+)\s*(<\d+>\s)\s*(.*\n)/mg){#It is old DATA format annon
                  $e = $1;
                  $t = $2;
                  $v = substr($tag,length($e)+length($t));
                  $anons->{$e} = $v;
                  next;
            }
            # Before mauling into possible value types, let us go for the full expected tag specs first:
            # <<{$sig}{name}<{INSTRUCTION}>{value\n...value\n}>>
            # Found in -> <https://github.com/wbudic/PerlCNF//CNF_Specs.md>
            if($tag !~ /\n/ && $tag =~ /^([@%\$\.\/\w]+)\s*([ <>]+)(\w*>)(.*)/) {
                $e = $1;
                $t = $2;
                if($t =~ /^<\s*</){
                   $v = substr $tag, length($e)+1;
                   $v =~ s/>$// if $t ne '<<' && $tag =~ />$/
                }else{
                    $tag =~ m/([@%\$\.\/\w]+) ([ <>\n|^\\]{1})+ ([^<^>^^\n]+) ([<>]?) (.*)/gmxs;
                         $t = $3;
                         $v = $5;
                }
            }else{
                                                #############################################################################
                $tag =~ m/\s*([@%\$\.\/\w]+)\s* # The name.
                                ([ <>\n])       # begin or close of instruction, where '\n' mark in script as instruction less.
                                ([^<^>^^\n]+)   # instruction or value of anything
                                    ([<>\n]?)   # close mark for instuction or is less if \n encountered before.
                                    (.*)        # actual value is the rest.
                                       (>$)*    # capture above value up to here from buffer, i.e. if comming from a >>> tag.
                         /gmxs;                 ###############################################################################

                $e =$1;
                if($e eq '@' or $2 eq '<' or ($2 eq '>' and !$4)){
                $t = $3;
                }else{
                $t = $1;
                $e = $3
                }
                $v= $5;
                $v =~ s/>$//m if defined($4) && $4 eq '<' or $6; #value has been crammed into an instruction?

            }
            if(!$v && !$RESERVED_WORDS{$t}){
                $v= $t;
            }
            $v =~ s/\\</</g; $v =~ s/\\>/>/g;# escaped brackets from v.2.8.

            #Do we have an autonumbered instructed list?
            #DATA best instructions are exempted and differently handled by existing to only one uniquely named property.
            #So its name can't be autonumbered.
            if ($e =~ /(.*?)\$\$$/){
                $e = $1;
                if($t && $t ne 'DATA'){
                   my $array = $lists{$e};
                   if(!$array){$array=();$lists{$e} = \@{$array};}
                   push @{$array}, InstructedDataItem -> new($e, $t, $v);
                   next
                }
            }elsif ($e eq '@'){#collection processing.
                my $isArray = $t=~ m/^@/;
                # if(!$v && $t =~ m/(.*)>(\s*.*\s*)/gms){
                #     $t = $1;
                #     $v = $2;
                # }
                my $IsConstant = ($v =~ s/$meta_const/""/sexi);
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
                            my @pair = ($p=~/\s*([-+_\w\$]*)\s*[=:]\s*(.*)/s);#split(/\s*=\s*/, $p);
                            next if (@pair != 2 || $pair[0] =~ m/^[#\\\/]+/m);#skip, it is a comment or not '=' delimited line.
                            my $name  = $pair[0];
                            my $value = $pair[1]; $value =~ s/^\s*["']|['"]$//g;#strip quotes
                            if($IsConstant && $name =~ m/\$[A-Z]+/){
                               if(not exists $self->{$name}){
                                  $self->{$name} = $value;
                                  next;
                               }
                            }
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
            doInstruction($self,$e,$t,$v)
        }
	}
    # Do scripted includes first. As these might set properties imported and processed used by the main script.
    if(@includes){
       $includes[@includes] = {script=>$CUR_SCRIPT,loaded=>1, prc_last=>0} if not includeContains($CUR_SCRIPT); #<- to prevent circular includes.
       foreach (@includes){
          $self -> doInclude($_) if $_ && not $_->{prc_last} and not $_->{loaded} and $_->{local} eq $CUR_SCRIPT;
       }
    }
    ###  Do the smart instructions and property linking.
    if(%instructs && not $IS_IN_INCLUDE_MODE){
        my @items;
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
                $items[@items] = $struct;
            }
        }

        @items =  sort {$a->{'^'} <=> $b->{'^'}} @items; #sort by priority;

        for my $idx(0..$#items) {
            my $struct = $items[$idx];
            my $type =  ref($struct);
            if($type eq 'CNFNode' && $struct-> priority() > 0){
               $struct->validate() if $self->{ENABLE_WARNINGS};
               $anons ->{$struct->name()} = $struct->process($self, $struct->script());
               splice @items, $idx, 1
            }
        }
        #Now only what is left instructed data items or plugins, and nodes that have assigned last priority, if any.
        for my $idx(0..$#items) {
            my $struct = $items[$idx];
            my $type =  ref($struct);
            if($type eq 'CNFNode'){
               $struct->validate() if $self->{ENABLE_WARNINGS};
               $anons->{$struct->name()} = $struct->process($self, $struct->script());
            }elsif($type eq 'InstructedDataItem'){
                my $t = $struct->{ins};
                if($t eq 'PLUGIN'){
                   instructPlugin($self,$struct,$anons);
                }
            }else{warn "What is -> $struct type:$type ?"}
        }
        undef %instructs;
    }

    foreach (@includes){
        $self -> doInclude($_) if $_ && (not $_->{loaded} and $_->{local} eq $CUR_SCRIPT)
    }
    undef @includes if not $IS_IN_INCLUDE_MODE;

    foreach my $k(@$del_keys){
        delete $self->{$k} if exists $self->{$k}
    }
    my $runProcessors = $self->{RUN_PROCESSORS} ? 1: 0;
    $self = lock_hash(%$self);#Make repository finally immutable.
    runPostParseProcessors($self) if $runProcessors;
    if ($LOG_TRIM_SUB){
        $LOG_TRIM_SUB->();
        undef $LOG_TRIM_SUB;
    }
    return $self
}
#
    sub includeContains{
        my $path = shift;
        foreach(@includes){
            return 1 if $_&&$_->{script} eq $path
        }
        return 0
    }
###
# Loads and parses includes local to script.
###
sub doInclude { my ($self, $prp_file) = @_;
    if(!$prp_file->{loaded}){
        my $file = $prp_file->{script};
        if(!-e $file){$file =~ m/.*\/(.*$)/; $file = $1}
        if(open(my $fh, "<:perlio", $file)){
            read $fh, my $content, -s $fh;
            close   $fh;
            if($content){
                my $cur_script = $CUR_SCRIPT;
                $prp_file->{loaded} = 1;
                $CUR_SCRIPT = $prp_file->{script};
                # Perl is not OOP so instructions are gathered into one place, time will tell if this is desirable rather then a curse.
                # As per file processing of instructions is not encapsulated within a included file, but main includer or startup script.
                $IS_IN_INCLUDE_MODE = 1;
                $self->parse(undef, $content);
                $IS_IN_INCLUDE_MODE = 0;
                $CUR_SCRIPT = $cur_script;
            }else{
                $self->error("Include content is blank for include -> ".$prp_file->{script})
            }
        }else{
                $prp_file->{loaded} = 0;
                $self->error("Script include not available for include -> ".$prp_file->{script});
                CNFParserException->throw("Can't open include ".$prp_file->{script}." -> $!") if $self->{STRICT};
        }
    }
}

sub instructPlugin {
    my ($self, $struct, $anons) = @_;
    try{
        $properties{$struct->{'ele'}} = doPlugin($self, $struct, $anons);
        $self->log("Plugin instructed ->". $struct->{'ele'});
    }catch($e){
        if($self->{STRICT}){
            CNFParserException->throw(error=>$e);
        }else{
            $self->trace("Error @ Plugin -> ". $struct->toString() ." Error-> $@")
        }
    }
}
#

###
# Register Instructor on tag and value for to be externally processed.
# $package  - Is the anonymouse package name.
# $body     - Contains attribute(s) linking to method(s) to be registered.
# @TODO Current Under development.
###
sub registerInstructor {
    my ($self, $package, $body) = @_;
    $body =~ s/^\s*|\s*$//g;
    my ($obj, %args, $ins, $mth);
    foreach my $ln(split(/\n/,$body)){
            my @pair = $ln =~ /\s*(\w+)[:=](.*)\s*/;
            $ins  = $1; $ins = $ln if !$ins;
            $mth  = $2;
            if($ins =~ /[a-z]/i){
               $args{$ins} = $mth;
            }
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
        $instructors{$ins} = \$obj
    }
    return \$obj;
}
#

###
# Register PostParseProcessor for further externally processing.
# $package  - Is the anonymouse package name.
# $body     - Contains attribute(s) where function is the most required one.
###
sub registerProcessor {
    my ($self, $package, $body) = @_;
        $body =~ s/^\s*|\s*$//g if $body;
    my ($obj, %args, $ins, $mth, $func);
    foreach my $ln(split(/\n/,$body)){
            my @pair = $ln =~ /\s*(\w+)[:=](.*)\s*/;
            $ins  = $1; $ins = $ln if !$ins;
            $mth  = $2;
            if($ins =~ /^func\w*/){
               $func = $mth
            }
            elsif($ins =~ /[a-z]/i){
               $args{$ins} = $mth
            }
    }
    $func = $ins if !$func;
    if(!$func){
         $self -> log("ERR <<$package<$body>> function attribute not found set.");
        return;
    }
    ## no critic (RequireBarewordIncludes)
    require $package.'.pm';
    my $methods =   Class::Inspector->methods($package, 'full', 'public');
    my ($has_new,$has_func);
    foreach(@$methods){
        $has_new  = 1 if $_ eq "$package\::new";
        $has_func = 1 if $_ eq "$package\::$func";
    }
    if(!$has_new){
        $self -> log("ERR In package $package -> new() method not found for package.");
        return;
    }
    if(!$has_func){
        $self -> log("ERR In package $package -> $func(\$parser) required method not found for package.");
        return;
    }
    $obj = $package -> new(\%args);
    $self->addPostParseProcessor($obj,$func);
    return 1;
}

sub addPostParseProcessor {
    my $self = shift;
    my $processor = shift;
    my $func = shift;
    my @arr;
    my $arf = $self->{POSTParseProcessors} if exists $self->{POSTParseProcessors};
    @arr = @$arf if $arf;
    $arr[@arr] =  [$processor, $func];
    $self->{POSTParseProcessors} = \@arr;
}

sub runPostParseProcessors {
    my $self = shift;
    my $arr = $self->{POSTParseProcessors} if exists $self->{POSTParseProcessors};
    foreach(@$arr){
        my @objdts =@$_;
        my $prc  = $objdts[0];
        my $func = $objdts[1];
        $prc -> $func($self);
    }
}

#

###
# Setup and pass to pluging CNF functionality.
# @TODO Current Under development.
###
sub doPlugin {
    my ($self, $struct, $anons) = @_;
    my ($elem, $script) = ($struct->{'ele'}, $struct->{'val'});
    my $plugin = PropertyValueStyle->new($elem, $script);
    my $pck = $plugin->{package};
    my $prp = $plugin->{property};
    my $sub = $plugin->{subroutine};
    if($pck && $prp && $sub){
        ## no critic (RequireBarewordIncludes)
        require "$pck.pm";
        #Properties are global, all plugins share a %Settings property if specifed, otherwise the default will be set from here only.
        my $settings = $properties{'%Settings'};
        if($settings){
           foreach(keys %$settings){
                #We allow for now, the plugin have settings set by its property, do not overwrite if exists as set.
                $plugin->{$_} =  $settings->{$_} unless exists $plugin->{$_}
           } ;
        }
        my $obj = $pck->new($plugin);
        my $res = $obj-> $sub($self, $prp);
        if($res){
           $plugin->setPlugin($obj);
           return $plugin;
        }else{
            die "Sorry, the PLUGIN feature has not been Implemented Yet!"
        }
    }
    else{
        die qq(Invalid plugin encountered '$elem' in "). $self->{'CNF_CONTENT'} .qq(
        Plugin must have attributes -> 'package', 'property' and 'subroutine')
    }
}

###
# Generic CNF Link utility on this repository.
##
sub obtainLink {
    my ($self,$link, $ret) = @_;
    my $meths;
    ## no critic BuiltinFunctions::ProhibitStringyEval
    no strict 'refs';
    if($link =~/(\w*)::\w+$/){
        use Module::Loaded qw(is_loaded);
        if(is_loaded($1)){
           $ret = \&{+$link}($self);
        }else{
           eval require "$1.pm";
           $ret = &{+$link};
           if(!$ret){
            $self->error( qq(Package  constance link -> $link is not available (try to place in main:: package with -> 'use $1;')));
            $ret = $link
           }
        }
    }else{
        $ret = $self->anon($link);
        $ret = $self-> {$link} if !$ret;
    }
    return $ret;
}

###
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
    my $type    = shift; $type = "" if !$type;
    my $isWarning = $type eq 'WARNG';
    my $attach  = join @_; $message .= $attach if $attach;
    my %log = $self -> property('%LOG');
    my $time = exists $self->{'TZ'} ? CNFDateTime -> new(TZ=>$self->{'TZ'}) -> toTimestamp() :
                                      CNFDateTime -> new()-> toTimestamp();

    $message = "$type $message" if $isWarning;

    if($message =~ /^ERROR/ || ($isWarning && $self->{ENABLE_WARNINGS})){
        warn  $time . " " .$message;
    }
    elsif(%log && $log{console}){
        print $time . " " .$message ."\n"
    }
    if(%log && _isTrue($log{enabled}) && $message){
        my $logfile  = $log{file};
        my $tail_cnt = $log{tail};
        if($logfile){
                        open (my $fh, ">>", $logfile) or die $!;
                        print $fh $time . " - " . $message ."\n";
                        close $fh;
                        if($tail_cnt>0 && !$LOG_TRIM_SUB){
                           $fh = File::ReadBackwards->new($logfile) or die $!;
                           if($fh->{lines}>$tail_cnt){
                                $LOG_TRIM_SUB = sub {
                                my $fh = File::ReadBackwards->new($logfile) or die $!;
                                my @buffer; $buffer[@buffer] = $fh->readline() for (1..$tail_cnt);
                                   open (my $fhTemp, ">", "/tmp/$logfile") or die $!;
                                    print $fhTemp $_ foreach (reverse @buffer);
                                    close $fhTemp;
                                   move("/tmp/$logfile",$logfile)
                                }
                           }
                        }
        }
    }
    return $time . " " .$message;
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
    if($self->{ENABLE_WARNINGS}){
       $self -> log($message,'WARNG');
    }
}
sub trace {
    my $self    = shift;
	my $message = shift;
    my %log = $self -> property('%LOG');
    if(%log){
        $self -> log($message)
    }else{
        cluck $message
    }
}

sub now {return CNFDateTime->new(shift)}

sub dumpENV{
    foreach (keys(%ENV)){print $_,"=", "\'".$ENV{$_}."\'", "\n"}
}

sub  SQL {
    if(!$SQL){##It is late compiled package on demand.
        my $self = shift;
        my $data = shift;
        require CNFSQL; $SQL  = CNFSQL->new({parser=>$self});
    }
    $SQL->addStatement(@_) if @_;
    return $SQL;
}
our $JSON;
sub  JSON {
    my $self = shift;
    if(!$JSON){
        require CNFJSON;
        $JSON = CNFJSON-> new({ CNF_VERSION => $self->{CNF_VERSION},
                                CNF_CONTENT => $self->{CNF_CONTENT},
                                DO_ENABLED  => $self->{DO_ENABLED}
                              });
    }
    return $JSON;
}

###
# CNFNodes are kept as anons by the TREE instruction, but these either could have been futher processed or
# externaly assigned too as nodes to the parser.
###
our %NODES;
sub addTree {
    my ($self, $name, $node  )= @_;
    if($name && $node){
        $NODES{$name} = $node;
    }
}
### Utility way to obtain CNFNodes from a configuration.
sub getTree {
    my ($self, $name) = @_;
    return $NODES{$name} if exists $NODES{$name};
    my $ret = $self->anon($name);
    if(ref($ret) eq 'CNFNode'){
        return \$ret;
    }
    return;
}

sub END {
$LOG_TRIM_SUB->() if $LOG_TRIM_SUB;
undef %ANONS;
undef @files;
undef %properties;
undef %lists;
undef %instructors;
}
1;
=begin copyright
Programed by  : Will Budic
EContactHash  : 990MWWLWM8C2MI8K (https://github.com/wbudic/EContactHash.md)
Source        : https://github.com/wbudic/PerlCNF.git
Documentation : Specifications_For_CNF_ReadMe.md
    This source file is copied and usually placed in a local directory, outside of its repository project.
    So it could not be the actual or current version, can vary or has been modiefied for what ever purpose in another project.
    Please leave source of origin in this file for future references.
Open Source Code License -> https://github.com/wbudic/PerlCNF/blob/master/ISC_License.md
=cut copyright

__END__
## Instructions & Reserved words

   1. Reserved words relate to instructions, that are specially treated, and interpreted by the parser to perform extra or specifically processing on the current value.
   2. Reserved instructions can't be used for future custom ones, and also not recommended tag or property names.
   3. Current Reserved words list is.
       - CONST    - Concentrated list of constances, or individaly tagged name and its value.
       - VARIABLE - Concentrated list of anons, or individaly tagged name and its value.
       - DATA     - CNF scripted delimited data property, having uniform table data rows.
       - DATE     - Translate PerlCNF date representation to DateTime object. Returns now() on empty property value.
       - FILE     - CNF scripted delimited data property is in a separate file.
       - %LOG     - Log settings property, i.e. enabled=>1, console=>1.
       - TABLE    - SQL related.
       - TREE     - Property is a CNFNode tree containing multiple debth nested children nodes.
       - INCLUDE  - Include properties from another file to this repository.
       - INDEX    - SQL related.
       - INSTRUCT - Provides custom new anonymous instruction.
       - VIEW     - SQL related.
       - PLUGIN   - Provides property type extension for the PerlCNF repository.
       - PROCESSOR- Registered processor to be called once all parsing is done and repository secured.
       - SQL      - SQL related.
       - MIGRATE  - SQL related.
       - MACRO
          1. Value is searched and replaced by a property value, outside the property scripted.
          2. Parsing abruptly stops if this abstract property specified is not found.
          3. Macro format specifications, have been aforementioned in this document. However make sure that your macro an constant also including the *$* signifier if desired.