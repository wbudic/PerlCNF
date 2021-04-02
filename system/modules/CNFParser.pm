#!/usr/bin/perl -w
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
package CNFParser;

use strict;
use warnings;
use Exception::Class ('CNFParserException');
use Try::Tiny;

our $VERSION = '2.1';



our %consts = ();
our %mig    = ();
our @sql    = ();
our @files  = ();
our %tables = ();
our %data   = ();
our %lists  = ();
our %anons  = ();
our %prps   = ();


sub new {
    my $class = shift;
    my $path = shift;
    my $self = {};
    bless $self, $class;
    $self->parse($path) if($path);
    return $self;
}


sub anons {
    my ($self, $n, @arg)=@_;
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
sub constant {my $s=shift;if(@_ > 0){$s=shift;} return $consts{$s}}
sub constants {my @ret = sort keys %consts; return @ret}
sub SQLStatments {@sql}
sub dataFiles {@files}
sub tables {keys %tables}
sub tableSQL {my $t=shift;if(@_ > 0){$t=shift;} return $tables{$t}}
sub dataKeys {keys %data}
sub data {my $t=shift;if(@_ > 0){$t=shift;} return @{$data{$t}}}
sub migrations {%mig;}
sub lists {\%lists}
sub list {my $t=shift;if(@_ > 0){$t=shift;} return @{$lists{$t}}}
sub collections {\%prps}
sub collection {my($self, $arr)=@_; %prps{$arr}}
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

# Adds a list of environment expected list of variables.
# This is optional and ideally to be called before parse.
# Requires and array of variables to be passed.
sub addENVList {
    my ($self, @vars) = @_;
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
    }
}


sub template {
    my ($self, $property, %macros) = @_;
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
    return;
}
my %hsh_test=();

sub parse {
        my ($self, $cnf, $content) = @_;
        open(my $fh, "<:perlio", $cnf )  or  CNFParserException->throw("Can't open $cnf -> $!");
        read $fh, $content, -s $fh;
        close $fh;
try{

    my @tags =  ($content =~ m/(<<)(\$*<?)(.*?)(>>+)/gs);
    
    
   # ($content =~ m/<<(\$*.*\w*\$*<(.*?).*?>+)/gs);
        
    foreach my $tag (@tags){             
	  next if not $tag;
      if(index($tag,'<CONST')==0){#constant multiple properties.

            foreach  (split '\n', $tag){
                my @prps = map {
                    s/^\s+\s+$//;  # strip unwanted spaces
                    s/^\"//;      # strip start quote
                    s/\"$//;      # strip end quote
                    s/<const\s//i; # strip  identifier
                    s/\s>>//;
                    $_          # return the modified string
                }
                split /\s*=\s*/, $_;

                my $k;
                foreach (@prps){
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
        elsif(index($tag,'CONST<')==0){#single property multiline constant.
            my $i = index $tag, "\n";
            my $k = substr $tag, 6, $i-6;
            my $v = substr $tag, $i, (rindex $tag, ">>")-$i;
            $consts{$k} = $v if not $consts{$k};
        }
        else{

            my ($st,$v);
            my @kv = split /</,$tag;
            my $e = $kv[0];
            my $t = $kv[1];
            my $i = index $t, "\n";
            #trim accidental spacing in property value or instruction tag
            $t =~ s/^\s+//g;
            if((@kv)==2 && $t =~ m/\w>$/){ # arbitary instructed and values
                $i = index $content, $tag;
                $i = $i + length($tag);
                $st = index $content, ">>", $i;
                if($st==-1){$st = index $content, "<<", $i}#Maybe still in old format CNF1.0
                if(substr($content, $i,1)eq'\n'){$i++}#value might be new line steped?
                $v = substr $content, $i, $st - $i ;

                $anons{$e} = "<$t"."\n".$v;
                next;
            }
            elsif(($e eq '@')){#evaluation of multiple properties
                my $isArray = $t=~ m/^@/;
                my $v = substr $kv[2], 0;
                my @lst = ($isArray?split('("+.*"+)|[,\n]', $v):split('\n', $v));
                my @props = map {
                        s/^\s+|\s+$//;     # strip unwanted spaces
                        s/^\s*\"//;      # strip start quote
                        s/\"\s*$//;      # strip end quote                    
                        s/\s>>//;
                        $_ ? $_ : undef   # return the modified string
                    } @lst;
                if($isArray){
                    my @arr=(); $prps{$t}=\@arr;
                    foreach  my $p(@props){
                        push @arr, $p if( length($p)>0);
                    }
                }else{
                    my %hsh=(); $prps{$t}=\%hsh;
                    foreach  my $p(@props){
                        if( length($p)>0 ){
                            my @pair = split(/\s*=\s*/, $p);
                            my $name = $pair[0]; $name =~ s/^\s*|\s*$//g;
                            my $value = $pair[1]; 
                            # my $ins= qq($t\{\"$name\"\}=\"$value\");                        
                            # eval ($ins);
                            $hsh{$name}=$value;
                            #if($@) { die "Error with $ins\n$@"}
                        }
                    }
                }
                next;
            }  


            #TODO This section is problematic, a instruction is not the value of the property. Space is after the instruction on single line.
            if($i==-1){#It is single line
                my $te = index $t, " ";
                if($te>0){
                    $v = substr($t, $te+1, (rindex $t, ">>")-($te+1));
                    if(isReservedWord($v)){
                        $t = substr($t, 0, $te);                       
                    }
                    else{
                        $v = $t =substr $t, 0, (rindex $t, ">>");#single line declared anon most likely.                     
                    }                    
                }
                else{
                     my $ri = (rindex $t, ">>>");
                        $ri = (rindex $t, ">>") if($ri==-1);
                        $t = $v = substr $t, 0, $ri;                   
                }
            }
            else{
               my $ri = (rindex $t, ">>>");
               $ri = (rindex $t, ">>") if($ri==-1);
               #print "[[1[$t]]]\n";
               if($ri>$i){
                    $v = substr $t, $i;
                    #opting to trim on multilines, just in case number of ending "<<" count is scripted in a mismatch!
                    $v =~ s/\s*>+$//g; 
                   # print "[[2[$e->$v]]\n";
               }
               else{
                    $v = substr $t, $i+1, $ri - ($i+2);
               }
               $t = substr $t, 0, $i;
            }

          # print "Ins($i): with $e do $t|\n";


           if($t eq 'CONST'){#Single constant with mulit-line value;
               $v =~ s/^\s//;
               $consts{$e} = $v if not $consts{$e};
               next;
           }
           elsif($t eq 'DATA'){
               $st ="";
               my @tad = ();
               foreach(split /~\n/,$v){
                   my $i = "";
                   $_ =~ s/\\`/\\f/g;#We escape to form feed  the escaped in file backtick.
                   foreach my $d (split /`/, $_){
                        $d =~ s/\\f/`/g; #escape back form feed to backtick.
                        $t = substr $d, 0, 1;
                        if($t eq '$'){
                            $v =  $d;            #capture spected value.
                            $d =~ s/\$$|\s*$//g; #trim any space and system or constant '$' end marker.
                            if($v=~m/\$$/){
                                $v = $consts{$d}
                            }
                            else{
                                $v = $d;
                            }
                            $i .= "'$v',";
                        }
                        else{
                            #First is always ID a number and '#' signifies number.
                            if($t eq "\#") {
                                $i .= "$d," if $d;
                            }
                            else{
                                $i .= "'$d',";
                            }
                        }
                   }
                   $i =~ s/,$//;
                   push @tad, $i if $i;
               }
                   my @existing = $data{$e};
                   if(scalar(@existing)>1){
                       @existing = @{$data{$e}};
                       foreach my $i(@existing){
                         push @tad, $i if $i;
                       }
                   }
                   $data{$e} = [@tad] if scalar(@tad)>0;
               next;
            }         
            elsif($t eq 'FILE'){

                    my $path = $cnf;
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
                            @kv = split /</,$tag;
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
                            $st ="";
                            my @tad = ();
                            foreach(split /~\n/,$v){
                                my $i = "";
                                $_ =~ s/\\`/\\f/g;#We escape to form feed  the escaped in file backtick.
                                foreach my $d (split /`/, $_){
                                        $d =~ s/\\f/`/g; #escape back form feed to backtick.
                                        $t = substr $d, 0, 1;
                                        if($t eq '$'){
                                            $v =  $d;            #capture spected value.
                                            $d =~ s/\$$|\s*$//g; #trim any space and system or constant '$' end marker.
                                            if($v=~m/\$$/){
                                                $v = $consts{$d}
                                            }
                                            else{
                                                $v = $d;
                                            }
                                            $i .= "'$v',";
                                        }
                                        else{
                                            #First is always ID a number and '#' signifies number.
                                            if($t eq "\#") {
                                                $i .= "$d," if $d;
                                            }
                                            else{
                                                $i .= "'$d',";
                                            }
                                        }
                                }
                                $i =~ s/,$//;
                                push @tad, $i if $i;
                            }
                            my @existing = $data{$e};
                            if(scalar(@existing)>1){
                                @existing = @{$data{$e}};
                                foreach my $i(@existing){
                                    push @tad, $i if $i;
                                }
                            }
                            $data{$e} = [@tad] if scalar(@tad)>0;
                        }
                   }
                next;
            }
            elsif($t eq 'TABLE'){
               $st = "CREATE TABLE $e(\n$v\n);";
               $tables{$e} = $st;
               next;
            }
            elsif($t eq 'INDEX'){
               $st = "CREATE INDEX $v;";
            }
            elsif($t eq 'VIEW'){
                $st = "CREATE VIEW $v;";
            }
            elsif($t eq 'SQL'){
                $st = $v;
            }
            elsif($t eq 'MIGRATE'){
                my @m = $mig{$e};
                   @m = () if(!@m);
                push @m, $v;
                $mig{$e} = [@m];
            }
            else{
                #Register application statement as either an anonymouse one. Or since v.1.2 an listing type tag.   
                #print "Reg($e): $v\n";
                if($e !~ /\$\$$/){ $anons{$e} = $v }
                else{
                    $e = substr $e, 0, (rindex $e, "$$")-1;
                    # Following is confusing as hell. We look to store in the hash an array reference.
                    # But must convert back and fort via an scalar, since actual arrays returned from an hash are references in perl.
                    my $a = $lists{$e};
                    if(!$a){$a=();$lists{$e} = \@{$a};}
                    push @{$a}, $v;
                    #print "Reg($e): $v [$a]\n";                  
                    
                }
                next;
            }
            push @sql, $st;#push as application statement.
        }
	 }

}catch{
      CNFParserException->throw(error=>$_, show_trace=>1);
};
}

my %RESERVED_WORDS = ( DATA=>1,  FILE=>1, TABLE=>1, INDEX=>1, VIEW=>1, SQL=>1, MIGRATE=>1 );
sub isReservedWord {return $RESERVED_WORDS{$_[1]}?1:0}

#sub isReservedWord {my $r = $RESERVED_WORDS{$_[1]}; $r = 0 if !$r;  return $r}

##
# Required to be called when using CNF with an database based storage.
#
sub initiDatabase {
    my($self,$db,$st,$dbver)=@_;
#Check and set SYS_CNF_CONFIG
try{
    $st=$db->do("select count(*) from SYS_CNF_CONFIG;");
    $st = $db->prepare('SELECT VALUE FROM SYS_CNF_CONFIG WHERE NAME LIKE "$RELEASE_VER";');
    $st->execute();
    my @r =  $st->fetchrow_array();
    $dbver = $r[0];
}
catch{
        # $st = $db->prepare('SELECT VALUE FROM SYS_CNF_CONFIG WHERE NAME LIKE "$RELEASE_VER";');
        # $st->execute() or warn "Missing!";
        # my @r  = $st->fetchrow_array();
        # return $r[0] if(@r);

        print "Missing SYS_CNF_CONFIG table, trying next to create it.\n";
        my $stmt = qq(
                CREATE TABLE SYS_CNF_CONFIG (
                    NAME VCHAR(16) NOT NULL,
                    VALUE VCHAR(28) NOT NULL,
                    DESCRIPTION VCHAR(128)
                );
        );
        $db->do($stmt);
        print "Created table: SYS_CNF_CONFIG \n";
        $st = $db->prepare('INSERT INTO SYS_CNF_CONFIG VALUES(?,?,?);');
        $db->begin_work();
        foreach my $key($self->constants()){
            my ($dsc,$val);
            $val = $self->constant($key);
            my @sp = split '`', $val;
            if(scalar @sp>1){$val=$sp[0];$dsc=$sp[1];}else{$dsc=""}
            $st->execute($key,$val,$dsc);
        }
        $db->commit();
        $dbver = $self -> constant('$RELEASE_VER');
};

return $dbver;

}


sub tableExists {
    my ($self, $db, $tbl) = @_;
    try{
        $db->do("select count(*) from $tbl;");
        return 1;

     }catch{
        return 0;
    }
}



###
# Buffer loads initiated a file for sql data instructions.
# TODO 2020-02-13 Under development.
#
sub initLoadDataFile {
    my($self, $path) = @_;
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
