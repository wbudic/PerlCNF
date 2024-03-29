###
# SQL Processing part for the Configuration Network File Format.
###
package CNFSQL;

use strict;use warnings;#use warnings::unused;
use Exception::Class ('CNFSQLException'); use Carp qw(cluck);
use Syntax::Keyword::Try;
use Time::HiRes qw(time);
use DateTime;
use DBI;
use Tie::IxHash;

use constant VERSION => '2.0';

our %tables = (); our %tables_id_type = ();
our %views  = ();
our %mig    = ();
our @sql    = ();
our @statements;
our %curr_tables  = ();

my $isPostgreSQL = 0;
my $hasRecords = 0;
my $TZ;


sub new {
    my ($class, $attrs, $self) = @_;
    $self = \%$attrs;
    # By convention any tables and views as appearing in the CNF script should in that order also be created.
    tie %tables, "Tie::IxHash";
    tie %views, "Tie::IxHash";
    bless $self, $class;
}


sub isPostgreSQL{shift; return $isPostgreSQL}

##
# Required to be called when using CNF with an database based storage.
# This subrotine is also a good example why using generic driver is not recomended.
# Various SQL db server flavours meta info is def. handled differently and not updated in them.
#
# $map - In general is binding of an CNF table to its DATA property, header of the DATA instructed property is self column resolving.
#        If assinged to an array the first element must contain the name,
#        @TODO 20231018 - Specifications page to be provided with examples for this.
#
sub initDatabase { my($self, $db, $do_not_auto_synch, $map, $st) = @_;
#Check and set CNF_CONFIG
try{
    $hasRecords   = 0;
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
                        NAME character varying(32)  NOT NULL,
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
        $db->begin_work();
        $db->do($stmt);
        $self->{parser}->log("CNFParser-> Created CNF_CONFIG table.");
        $st = $db->prepare('INSERT INTO CNF_CONFIG VALUES(?,?,?);');
        foreach my $key(sort keys %{$self->{parser}}){
            my ($dsc,$val);
            $val = $self->{parser}->const($key);
            if(ref($val) eq ''){
                my @sp = split '`', $val;
                if(scalar @sp>1){$val=$sp[0];$dsc=$sp[1];}else{$dsc=""}
                $st->execute($key,$val,$dsc);
            }
        }
        $db->commit();
    }else{ unless ($do_not_auto_synch){
        my $sel = $db->prepare("SELECT VALUE FROM CNF_CONFIG WHERE NAME LIKE ?;");
        my $ins = $db->prepare('INSERT INTO CNF_CONFIG VALUES(?,?,?);');
        foreach my $key(sort keys %{$self->{parser}}){
                my ($dsc,$val);
                $val = $self->{parser}->const($key);
                if(ref($val) eq ''){
                    $sel->execute($key);
                    my @a = $sel->fetchrow_array();
                    if(@a==0){
                        my @sp = split '`', $val;
                        if(scalar @sp>1){$val=$sp[0];$dsc=$sp[1];}else{$dsc=""}
                        $ins->execute($key,$val,$dsc);
                    }
                }
        }
    }}
    # By default we automatically data insert synchronize script with database state on every init.
    # If set $do_not_auto_synch = 1 we skip that if table is present, empty or not,
    # and if has been updated dynamically that is good, what we want. It is of external config. implementation choice.
    foreach my $tbl(keys %tables){
        if(!$curr_tables{$tbl}){
            $st = $tables{$tbl};
            $self->{parser}->log("CNFParser-> SQL: $st\n");
            try{
                $db->do($st);
                $self->{parser}->log("CNFParser-> Created table: $tbl\n");
                $do_not_auto_synch = 0;
            }catch{
                die "Failed to create:\n$st\nError:$@"
            }
        }
        else{
            next if $do_not_auto_synch;
        }
    }
    foreach my $tbl(keys %tables){
        next if $do_not_auto_synch;
        my @table_info;
        my $tbl_id_type = $tables_id_type{$tbl};
        if(isPostgreSQL()){
           $st = lc $tbl; #we lc, silly psql is lower casing meta and case sensitive for internal purposes.
           $st="select ordinal_position, column_name, data_type from information_schema.columns where table_schema = 'public' and table_name = '$st';";
           $self->{parser}->log("CNFParser-> $st", "\n");
           $st = $db->prepare($st);
        }else{
           $st = $db->prepare("pragma table_info($tbl)");
        }
        $st->execute();
        while(my @row_info = $st->fetchrow_array()){
           $row_info[2] =~ /(\w+)/;
           $table_info[@table_info] = [$row_info[1], uc $1 ]
        }
        my $t = $tbl; my ($sel,$ins,@spec,$q,$qinto);
           $t  = %$map{$t} if $map && %$map{$t};
        if(ref($t) eq 'ARRAY'){
           @spec = @$t;
           $t = $spec[0]; shift @spec;
           foreach(@spec){ $q.="\"$_\" == ? and " }
           $q =~ s/\sand\s$//;
           $st="SELECT * FROM $tbl WHERE $q;";
           $self->{parser}->log("CNFParser-> $st\n");
           $sel = $db -> prepare($st);
        }else{
           my $prime_key = getPrimaryKeyColumnNameWherePart($db, $tbl);
           $st="SELECT * FROM $tbl WHERE $prime_key";
           $self->{parser}->log("CNFParser-> $st\n");
           $sel = $db -> prepare($st);
           my @r = $self->selectRecords($db,"select count(*) from $tbl;")->fetchrow_array();
           $hasRecords = 1 if $r[0] > 0
        }

        $q = $qinto = ""; my $qa = $tbl_id_type eq 'CNF_INDEX'; foreach(@table_info){
            if($qa || @$_[0] ne 'ID') {
                $qinto .="\"@$_[0]\",";
                $q.="?,"
            }
        }
        $qinto =~ s/,$//;
        $q =~ s/,$//;
        $ins = $db -> prepare("INSERT INTO $tbl ($qinto)\nVALUES ($q);");


        my $data = $self->{parser} -> {'__DATA__'};
        if($data){
            my  $data_prp = %$data{$t};
            if(!$data_prp && $self->{data}){
                $data_prp = %{$self->{data}}{$t};
            }
            if($data_prp){
                my @hdr;
                my @rows = @$data_prp;
                my $auto_increment=0;
            $db->begin_work();
                for my $row_idx (0 .. $#rows){
                    my @col = @{$rows[$row_idx]};
                    if($row_idx==0){
                        for my $i(0 .. $#col){
                            $hdr[@hdr]={'_'=>$col[$i],'i'=>$i}
                        }
                    }elsif(@col>0){
                        ##
                        #sel tbl section
                        if(@spec){
                           my @trans = ();
                           foreach my $name (@spec){
                              foreach(@hdr){
                                my $hn = $_->{'_'};
                                my $hi = $_->{'i'};
                                if($name =~ m/ID/i){
                                   if($col[$hi]){
                                      $trans[@trans] = $col[$hi];
                                   }else{
                                      $trans[@trans] = $row_idx; # The row index is ID as default on autonumbered ID columns.
                                   }
                                   last
                                }elsif($name =~ m/$hn/i){
                                   $trans[@trans] = $col[$hi];
                                   last
                                }
                              }
                           }
                           next if @trans && hasEntry($sel, \@trans);
                        }else{
                           next if hasEntry($sel, $row_idx); # ID is assumed autonumbered on by default
                        }
                        ##
                        my @ins = ();
                        foreach(@hdr){
                            my $hn = $_->{'_'};
                            my $hi = $_->{'i'};
                            for my $i(0 .. $#table_info){
                                if ($table_info[$i][0] =~ m/$hn/i){
                                    if($table_info[$i][0]=~/ID/i){
                                      if($col[$hi]){
                                         $ins[$i] = $col[$hi];
                                      }else{
                                         $ins[$i] = $row_idx; # The row index is ID as default on autonumbered ID columns.
                                      }
                                      $auto_increment=$i+1 if $tbl_id_type eq 'AUTOINCREMENT';
                                    }else{
                                       my $v = $col[$hi];
                                       if($table_info[$i][1] =~ /TIME/ || $table_info[$i][1] =~  /DATE/){
                                          $TZ = exists $self->{parser}->{'TZ'} ? $self->{parser}->{'TZ'} : CNFDateTime::DEFAULT_TIME_ZONE() if !$TZ;
                                          if($v && $v !~ /now|today/i){
                                                if($self->{STRICT}&&$v!~/^\d\d\d\d-\d\d-\d\d/){
                                                $self-> warn("Invalid date format: $v expecting -> YYYY-MM-DD at start as possibility of  DD-MM-YYYY or MM-DD-YYYY is ambiguous.")
                                                }
                                             $v = CNFDateTime::_toCNFDate($v,$TZ) -> toTimestamp()
                                          }else{
                                             $v = CNFDateTime->new({TZ=>$TZ}) -> toTimestamp()
                                          }
                                       }elsif($table_info[$i][1] =~ m/^BOOL/){
                                             $v = CNFParser::_isTrue($v) ?1:0;
                                       }
                                       $ins[$i] = $v
                                    }
                                    last;
                                }
                             }
                        }
                        $self->{parser}->log("CNFParser-> Insert into $tbl -> ". join(',', @ins)."\n");
                        if($auto_increment){
                           $auto_increment--;
                           splice @ins, $auto_increment, 1
                        }
                        $ins->execute(@ins);
                    }
                }
                $db->commit()
            }else{
                $self->{parser}->log("CNFParser-> No data collection is available for $tbl\n");
            }
        }else{
            $self->{parser}->log("CNFParser-> No data collection scanned for $tbl\n");
        }

    }

    foreach my $view(keys %views){
        if(!$curr_tables{$view}){
            $st = $views{$view};
            $self->{parser}->log("CNFParser-> SQL: $st\n");
            $db->do($st);
            $self->{parser}->log("CNFParser-> Created view: $view\n")
        }
    }
    undef %tables; undef %tables_id_type;
    undef %views;
}
catch{
  CNFSQLException->throw(error=>$@, show_trace=>1);
}
return $self->{parser}-> const('$RELEASE_VER');
}

sub _connectDB {
    my ($user, $pass, $source, $store, $path) = @_;
    if($path && ! -e $path){
       $path =~ s/^\.\.\/\.\.\///g;
    }else{
        $path = ""
    }
    my $DSN = $source .'dbname='.$path.$store;
    try{
        return DBI->connect($DSN, $user, $pass, {AutoCommit => 1, RaiseError => 1, PrintError => 0, show_trace=>1});
    }catch{
       die "<p>Error->$@</p><br><pre>DSN: $DSN</pre>";
    }
}
sub _credentialsToArray{
   return split '/', shift
}

sub createTable { my ($self, $name, $body, $idType) = @_;
        $tables{$name} = "CREATE TABLE $name(\n$body);";
        $tables_id_type{$name} = $idType;
}
sub createView { my ($self, $name, $body) = @_;
        $views{$name} = "CREATE VIEW $name AS $body;"
}
sub createIndex { my ($self, $body) = @_;
        my $st = "CREATE INDEX $body;";
        push @sql, $st;
}
sub migrate { my ($self, $name, $value) = @_;
        my @m = $mig{$name};
            @m = () if(!@m);
        push @m, $value;
        $mig{$name} = [@m];
}
sub addStatement { my ($self, $name, $value) = @_;
    $self->{$name}=$value;
}
sub getStatement { my ($self, $name) = @_;
   return $self->{$name} if exists $self->{$name};
   return;
}
sub hasEntry{  my ($sel, $uid) = @_;
    return 0 if !$hasRecords;
    if(ref($uid) eq 'ARRAY'){
           $sel -> execute(@$uid)
    }else{
           $uid=~s/^["']|['"]$//g;
           $sel -> execute($uid)
    }
    my @r=$sel->fetchrow_array();
    return scalar(@r);
}

sub getPrimaryKeyColumnNameWherePart { my ($db,$tbl) = @_; $tbl = lc $tbl;
    my $sql = $isPostgreSQL ?
qq(SELECT a.attname, format_type(a.atttypid, a.atttypmod) AS data_type
FROM   pg_index i
JOIN   pg_attribute a ON a.attrelid = i.indrelid
                     AND a.attnum = ANY(i.indkey)
WHERE  i.indrelid = '$tbl'::regclass
AND    i.indisprimary;) :

qq(PRAGMA table_info($tbl););


my $st = $db->prepare($sql); $st->execute();
my @r  = $st->fetchrow_array();
if(!@r){
    CNFSQLException->throw(error=> "Table missing or has no Primary Key -> $tbl", show_trace=>1);
}
        if($isPostgreSQL){
            return "\"$r[0]\"=?";
        }else{
            # sqlite
            # cid[0]|name|type|notnull|dflt_value|pk<--[5]
            while(!$r[5]){
                @r  = $st->fetchrow_array();
                if(!@r){
                CNFSQLException->throw(error=> "Table  has no Primary Key -> $tbl", show_trace=>1);
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
                CNFSQLException->throw(error=>"Database error encountered!\n ERROR->$@\n SQL-> $sql DSN:".$db, show_trace=>1);
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

sub END {
undef %tables;undef %views;
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