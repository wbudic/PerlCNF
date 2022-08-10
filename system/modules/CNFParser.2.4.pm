#!/usr/bin/perl -w
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
package CNFParser;

use strict;
use warnings;#use warnings::unused;
use Exception::Class ('CNFParserException');
use Syntax::Keyword::Try;
use Scalar::Util;
# Do not remove the following no critic, no security or object issues possible. 
# We can use perls default behaviour on return.
##no critic qw(Subroutines::RequireFinalReturn)

use constant VERSION => '2.4';

our %consts = ();
our %mig    = ();
our @sql    = ();
our @files  = ();
our %tables = ();
our %views  = ();
our %data   = ();
our %lists  = ();
our %anons  = ();
our %properties   = ();
our $CONSTREQ = 0;

sub new { my ($class, $path, $attrs, $self) = @_;
    if ($attrs){
        $self = \%$attrs;
        $CONSTREQ = $self->{'CONSTANT_REQUIRED'};
    }else{
        $self = {"DO_enabled"=>0}; # Enable/Disable DO instruction.
    }    
    bless $self, $class;
    $self->parse($path) if($path);
    return $self;
}

sub anon {  my ($self, $n, @arg)=@_;
    if($n){
        my $ret = $anons{$n};
        return if !$ret;
        if(@arg){
            my $cnt = 1;
            foreach(@arg){
                $ret =~ s/\$\$\$$cnt\$\$\$/$_/g;
                $cnt++;
            }
        }
        return $ret;
    }
    return %anons;
}
sub constant  {my $s=shift;if(@_ > 0){$s=shift;} return $consts{$s} unless $CONSTREQ; 
               my $r=$consts{$s}; return $r if defined($r); return CNFParserException->throw("Required constants variable ' $s ' not defined in config!")}
sub constants {\%consts}

sub collections {\%properties}
sub collection {my($self, $attr)=@_;return $properties{$attr}}
sub data {\%data}

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
sub list  {my $t=shift;if(@_ > 0){$t=shift;} my $a = $lists{$t}; return @{$a} if defined $a; die "Error: List name '$t' not found!"}


our %curr_tables  = ();
our $isPostgreSQL = 0;

sub isPostgreSQL{shift; return $isPostgreSQL}# Enabled here to be called externally.
my %RESERVED_WORDS = (CONST=>1, DATA=>1,  FILE=>1, TABLE=>1, 
                      INDEX=>1, VIEW=>1,  SQL=>1,  MIGRATE=>1, DO=>1, MACRO=>1 );
sub isReservedWord {my ($self, $word)=@_; return $RESERVED_WORDS{$word}}

# Adds a list of environment expected list of variables.
# This is optional and ideally to be called before parse.
# Requires and array of variables to be passed.
sub addENVList { my ($self, @vars) = @_;
    if(@vars){
        foreach my $var(@vars){
            next if $consts{$var};##exists already.
            if((index $var,0)=='$'){#then constant otherwise anon
                $consts{$var} = $ENV{$var};
            }
            else{
                $anons{$var} = $ENV{$var};
            }
        }
    }return;
}


sub template { my ($self, $property, %macros) = @_;    
    my $val = anons($self, $property);
    if($val){       
       foreach my $m(keys %macros){
           my $v = $macros{$m};
           $m ="\\\$\\\$\\\$".$m."\\\$\\\$\\\$";
           $val =~ s/$m/$v/gs;
       #    print $val;
       }
       my $prev;
       foreach my $m(split(/\$\$\$/,$val)){
           if(!$prev){
               $prev = $m;
               next;
           }
           undef $prev;
           my $pv = anons($self, $m);
           if(!$pv){
               $pv = constant($self, '$'.$m);
           }
           if($pv){
               $m = "\\\$\\\$\\\$".$m."\\\$\\\$\\\$";
               $val =~ s/$m/$pv/gs;
           }
       }
       return $val;
    }    
}

package InstructedDataItem {
    our $dataItemCounter = int(0);
    sub new { my ($class, $ins, $val) = @_;
        bless {
                aid => $dataItemCounter++,
                ins => $ins,
                val => $val
        }, $class;  return $class;      
    }
}

sub parse { my ($self, $cnf, $content) = @_;
try{
    my @tags;
    my $DO_enabled = $self->{'DO_enabled'};
    my %instructs; 
    if(!$content){
        open(my $fh, "<:perlio", $cnf )  or  die "Can't open $cnf -> $!";
        read $fh, $content, -s $fh;
        close $fh;
    }elsif( Scalar::Util::reftype($content) eq 'ARRAY'){
        $content = join  "",@$content;
    }
    @tags =  ($content =~ m/(<<)(<*.*?)(>>+)/gms);
    
               
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
                    s/\s>>//;
                    $_          # return the modified string
                }   split /\s*=\s*/, $_;                
                foreach (@properties){
                      if ($k){
                            $consts{$k} = $_ if not $consts{$k};
                            undef $k;
                      }
                      else{
                            $k = $_;
                      }
                }
            }

        }        
        else{
            my ($st,$e,$t,$v, $v3, $i) = 0;                     
            my @vv = ($tag =~ m/(@|[\$@%]*\w*)(<|>)/g);
            $e = $vv[$i++]; $e =~ s/^\s*//g;            
            die "Encountered invalid tag formation -> $tag" if(!$e);
            if($e eq '$$' && $tag =~ m/(\w*)\$*<((\s*.*\s*)*)/){ #we have an autonumbered instructed list.
               $e = $1;
               $t = $2;
               $v = $3;
               if (!$v){


                   if($tag =~ m/(\w*)\$*<(\s*.*\s*)>(\s*.*\s*)/){
                      $t = $2; $v = $3;
                   }
                   elsif($tag =~ m/<((.*\s*)*)>((.*\s*)*)/){                       
                      $t = $1; $v = $3;

                   }
                   elsif( $t=~m/(.*)>(.*)/ ){
                         $t = $1; $v = $2;
                   }
                   else{
                    $v=$tag
                   }
               }
               my $a = $lists{$e};
               if(!$a){$a=();$lists{$e} = \@{$a};}
               push @{$a}, new InstructedDataItem($t,$v);
               next;
            }
            # Is it <name><tag>value? Notce here, we are using here perls feature to return undef on unset array elements,
            # other languages throw exception. And reg. exp. set variables. So the folowing algorithm is for these languages unusable.
            while(defined $vv[$i] && $vv[$i] eq '>'){ $i++; }            
            $i++;
            $t = $vv[$i++]; 
            $v = $vv[$i++];
            if(!$v&&!$t&& $tag =~ m/(.*)(<)(.*)/g){# Maybe it is the old format wee <<{name}<{instruction} {value}...
                $t = $1; if (defined $3){$v3 = $3}else{$v3 = ""} $v = $v3;            
                my $w = ($v=~/(^\w+)/)[0];
                if(not defined $w){$w=""}
                if($e eq $t && $t eq $w){
                   $i=-1;$t="";
                }elsif($RESERVED_WORDS{$w}){        
                    $t = $w;
                    $i = length($e) + length($w) + 1;                  
                }else{                      
                    if($v3){$i=-1;$t=$v} #$3 is containing the value, we set the tag to it..
                    else{
                            $i = length($e) + 1;
                    }
                }
                $v = substr $tag, $i if $i>-1;  $v3 = '_V3_SET';
                           
            }elsif (!$t && $v =~ /[><]/){ #it might be {tag}\n closed, as supposed to with '>'
               my $l = length($e);
                  $i = index $tag, "\n";
                  $t = substr $tag, $l + 1 , $i -$l - 1;
                  $v3 = '_SUBS1_SET';
            }else{                  
                  $i = length($e) + length($t) + ($i - 3);
                  $v3 = '_SUBS2_SET';
            }

            #trim accidental spacing in property value or instruction tag
            $t =~ s/^\s+//g;
            # Here it gets tricky as rest of markup in the whole $tag could contain '<' or '>' as text characters, usually in multi lines.
            $v = substr $tag, $i if $v3 ne '_V3_SET';
            $v =~ s/^[><\s]*//g if $v3 ne '_SUBS1_SET';

           # print "<<$e>>\nt:<<$t>>\nv:<<$v>>\n\n";

            if($e eq '@'){#collection processing.
                my $isArray = $t=~ m/^@/;                
                my @lst = ($isArray?split(/[,\n]/, $v):split('\n', $v)); $_="";
                my @props = map {
                        s/^\s+|\s+$//;   # strip unwanted spaces
                        s/^\s*["']|['"]$//g;#strip qoutes
                        s/\s>>//;
                        $_ ? $_ : undef   # return the modified string
                    } @lst;
                if($isArray){
                    my @arr=(); $properties{$t}=\@arr;
                    foreach  (@props){                        
                        push @arr, $_ if( length($_)>0);
                    }
                }else{
                    my %hsh=(); $properties{$t}=\%hsh; my $macro = 0;
                    foreach  my $p(@props){ 
                        if($p && $p eq 'MACRO'){$macro=1}
                        elsif( $p && length($p)>0 ){                            
                            my @pair = split(/\s*=\s*/, $p);
                            die "Not '=' delimited-> $p" if scalar( @pair ) != 2;
                            my $name  = $pair[0]; $name =~ s/^\s*|\s*$//g;
                            my $value = $pair[1]; $value =~ s/^\s*["']|['"]$//g;#strip qoutes
                            if($macro){
                                foreach my $find($v =~ /(\$.*\$)/g) {                                   
                                    my $s= $find; $s =~ s/^\$\$\$|\$\$\$$//g;
                                    my $r = $anons{$s};                                    
                                    $r = $consts{$s} if !$r;
                                    $r = $instructs{$s} if !$r;
                                    die "Unable to find property for $t.$name -> $find\n" if !$r;                                    
                                    $value =~ s/\Q$find\E/$r/g;                    
                                }
                            }
                            $hsh{$name}=$value;  print "macro $t.$name->$value\n" 
                        }
                    }
                }
                next;
            }              

            if($t eq 'CONST'){#Single constant with mulit-line value;
               $v =~ s/^\s//;
               $consts{$e} = $v if not $consts{$e}; # Not allowed to overwrite constant.
            }elsif($t eq 'DATA'){

               foreach(split /~\n/,$v){
                   my @a;
                   $_ =~ s/\\`/\\f/g;#We escape to form feed  the found 'escaped' backtick so can be used as text.
                   foreach my $d (split /`/, $_){
                        $d =~ s/\\f/`/g; #escape back form feed to backtick.
                        $t = substr $d, 0, 1;
                        if($t eq '$'){
                            $v =  $d;            #capture spected value.
                            $d =~ s/\$$|\s*$//g; #trim any space and system or constant '$' end marker.
                            if($v=~m/\$$/){
                                $v = $consts{$d}; $v="" if not $v;
                            }
                            else{
                                $v = $d;
                            }
                            push @a, $v;
                        }
                        else{
                            #First is always ID a number and '#' signifies number.
                            if($t eq "\#") {
                                $d = substr $d, 1;
                                $d=0 if !$d; #default to 0 if not specified.
                                push @a, $d
                            }
                            else{
                              push @a, $d;
                            }
                        }
                   }                   
                   
                   my $existing = $data{$e};
                   if(defined $existing){
                        my @rows = @$existing;
                        push @rows, [@a] if scalar @a >0; 
                        $data{$e} = \@rows
                   }else{
                        my @rows; push @rows, [@a];   
                        $data{$e} = \@rows if scalar @a >0;   
                   }
               }
                next;
            }elsif($t eq 'FILE'){

                    my ($i,$path) = $cnf;
                    $v=~s/\s+//g;
                    $path = substr($path, 0, rindex($cnf,'/')) .'/'.$v;
                    push @files, $path;
                    next if(!$consts{'$AUTOLOAD_DATA_FILES'});
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
                            $t =  substr $t, 0, $i;
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
                                            $v = $consts{$d}; $v="" if not $v;
                                        }
                                        else{
                                            $v = $d;
                                        }
                                        push @a, $v;
                                    }
                                    else{
                                        #First is always ID a number and '#' signifies number.
                                        if($t eq "\#") {
                                            $d = substr $d, 1;
                                            $d=0 if !$d; #default to 0 if not specified.
                                            push @a, $d
                                        }
                                        else{
                                        push @a, $d; 
                                        }                                                
                                    }                   
                                    
                                    my $existing = $data{$e};
                                    if(defined $existing){
                                            my @rows = @$existing;
                                            push @rows, [@a] if scalar @a >0; 
                                            $data{$e} = \@rows
                                    }else{
                                            my @rows; push @rows, [@a];   
                                            $data{$e} = \@rows if scalar @a >0;   
                                    }
                                }   
                            }
                        }       
                    }
              next  
            }
            elsif($t eq 'TABLE'){
               $st = "CREATE TABLE $e(\n$v);";
               $tables{$e} = $st;
               next;
            }
            elsif($t eq 'INDEX'){
               $st = "CREATE INDEX $v;";
            }
            elsif($t eq 'VIEW'){
                $st = "CREATE VIEW $e AS $v;";
                $views{$e} = $st;
                next;
            }
            elsif($t eq 'SQL'){
                $anons{$e} = $v;
            }
            elsif($t eq 'MIGRATE'){
                my @m = $mig{$e};
                   @m = () if(!@m);
                push @m, $v;
                $mig{$e} = [@m];
            }
            elsif($DO_enabled && $t eq 'DO'){
                $_ = eval $v; chomp $_; $anons{$e} = $_
            }
            elsif($t eq 'MACRO'){
                  %instructs = () if(not %instructs);
                  $instructs{$e}=$v;                  
            }
            else{
                #Register application statement as either an anonymouse one. Or since v.1.2 an listing type tag.                 
                if($e !~ /\$\$$/){ #<- It is not matching {name}$$ here.
                    if($e=~/^\$/){
                        $consts{$e} = $v if !$consts{$e}; # Not allowed to overwrite constant.
                    }else{
                        if(defined $t && length($t)>0){ #unknow tagged instructions value we parse for macros.
                            %instructs = () if(not %instructs);
                            $instructs{$e}=$t;                                
                        }else{
                            $anons{$e} = $v # It is allowed to overwite and abuse anons.
                        }
                    }
                }
                else{
                    $e = substr $e, 0, (rindex $e, '$$')-1;
                    # Following is confusing as hell. We look to store in the hash an array reference.
                    # But must convert back and fort via an scalar, since actual arrays returned from an hash are references in perl.
                    my $a = $lists{$e};
                    if(!$a){$a=();$lists{$e} = \@{$a};}
                    push @{$a}, $v;
                }
                next;
            }
            push @sql, $st;#push as application statement.
        }
	}
    if(%instructs){ my $v;
        foreach my $e(keys %instructs){
            my $t = $instructs{$e}; $v=$t; #<--Instructions assumed as a normal value, case: <<{name}<{instruction}>>>
            foreach my $find($t =~ /(\$.*\$)/g) {                                   
                    my $s= $find; $s =~ s/^\$\$\$|\$\$\$$//g;# <- MACRO TAG
                    my $r = $anons{$s};
                    $r = $consts{$s} if !$r;                                           
                    die "Unable to find property for $e-> $find\n" if !$r;
                    $v = $t;
                    $v =~ s/\Q$find\E/$r/g;
                    $t = $v;
            }
            $anons{$e}=$v;
        }undef %instructs;
    }
}catch{
      CNFParserException->throw(error=>$@, show_trace=>1);
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
        @r = @{$data{$tbl}};
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
    undef %data;
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

sub selectRecords { my ($self, $db, $sql) = @_;
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
      $prp = $anons{$property};
      $prp = $consts{$property} if !$prp;
      die "Property not found -> $property" if !$prp;
      print $handle "<<$property><$prp>>\n";
      return 0;
    }
}

###
# Closes any buffered files and clears all data for the parser.
# TODO 2020-02-13 Under development.
#
sub END {

undef %anons;
undef %consts;
undef %mig;
undef @sql;
undef @files;
undef %tables;
undef %data;

}

### CGI END
1;