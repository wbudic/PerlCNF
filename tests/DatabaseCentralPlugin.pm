package DatabaseCentralPlugin;

use strict;
use warnings;

use feature qw(signatures);
use Scalar::Util qw(looks_like_number);
use Date::Manip;
use Time::Piece;
use DBI;
use Exception::Class ('PluginException');
use Syntax::Keyword::Try;
use Clone qw(clone);


my  ($isSQLite,%tables)=(0,());

sub new ($class, $plugin){
    my $settings;
    if($plugin){
       $settings = clone $plugin; #clone otherwise will get hijacked with blessings.
       $settings->{Language}='English' if not exists $settings->{Language};
       $settings->{DateFormat}='US'    if not exists $settings->{DateFormat}
    }else{
       $settings = {Language=>'English',DateFormat=>'US'}
    }
    Date_Init("Language=".$settings->{Language},"DateFormat=".$settings->{DateFormat}); #<-- Hey! It is not mine fault, how Date::Manip handles parameters.
    return bless $settings, $class
}
sub getConfigFiles($self, $parser, $property){
    my @dirs = $parser->collection($property);
    my @files = ['ID','path','size','lines','modified']; my $cnt=0; #We have to mimic CNF<DATA> type entries.
    foreach(@dirs){
        my @list = glob("$_/*.cnf $_/*.config");
        foreach my$fl(@list){
            my @stat = stat($fl);
            my $epoch_timestamp = $stat[9];
            my $size =  $stat[7];
            my $timestamp  = localtime($epoch_timestamp);
            my $CNFDate = $timestamp->strftime('%Y-%m-%d %H:%M:%S %Z');
            my $num_lines = do { 
                open my $fh, '<', $fl or die "Can't open $fl: $!";
                grep { not /^$|^\s*#/ } <$fh>; 
            };
            push @files, [++$cnt,$fl,$size,$num_lines,$CNFDate] if @list
        }
    }
    $parser->data()->{$self->{element}} = \@files;

}
sub main ($self, $parser, $property) {
    my $item =  $parser->anon($property);
    die "Property not found [$property]!" if !$item;
    my $datasource = $self->{DBI_SQL_SOURCE};
    die "DBI_SQL_SOURCE not set!" if !$item;
    my $dbname  = $self->{DB};
    die "DB not set!" if !$item;
    my $dbcreds = $self->{DB_CREDENTIALS};
    my ($dsn,$db);
    try{
    my ($u,$p) = split '/', $dbcreds;
        $isSQLite =  $datasource =~ /DBI:SQLite/i;
        $dbname .= '.db' if $isSQLite;
        $dsn = $datasource .'dbname='.$dbname;
        $db  = DBI->connect($dsn, $u, $p, {AutoCommit => 1, RaiseError => 1, PrintError => 0, show_trace=>1});
        if($isSQLite){
            my $pst	= $db->prepare("SELECT name FROM sqlite_master WHERE type='table' or type='view';");
            die if !$pst;
            $pst->execute();
            while(my @r = $pst->fetchrow_array()){
                $tables{$r[0]} = 1;
            }
        }else{
            my @tbls = $db->tables(undef, 'public');
            foreach (@tbls){
                my $t = uc substr($_,7); # We check for tables in uc.
                $tables{$t} = 1;
            }
        }
    }catch{
       PluginException->throw(error=>"<p>Error->$@</p><br><pre>DSN: $dsn</pre>",  show_trace=>1);
    }

    my $ref = ref($item);
    if($ref eq 'CNFNode'){
       my @tables = @{$item -> find('table/*')};
       warn "Not found any 'table/*' path elements for CNF property :". $item->name() if not @tables;
       foreach my $tbl(@tables){
         if(processTable($db,$tbl)){
            if($tbl -> {property}){
                my $process = processData($parser, $tbl -> {property});
                my $dbsTblInsert = $db->prepare($tbl -> {sqlInsert});
                my @spec = @$process[0];
                my @hdrc = @$process[1];
                my @data = @$process[2];
                my @idx = ();
                my @map  = @{$tbl -> {_MAPPING_}};
                my @hdr  = @{$hdrc[0][0]};
                   @data = @{$data[0][0]};
                ###
                # Follwing is rare to see in code, my (wbudic) forward override conditional mapping algorithm,
                # as actual data @row length could be larger to the relative column map, of what we are inserting.
                # I know, it looks like a unlocking a magick riddle.
                #
                if(@hdr){
                    for(my $i=0; $i<@hdr; $i++){
                        my $label = $hdr[$i];
                        my $j=0;
                        foreach (@map){
                            my @set  = @$_;
                            if($set[0] eq $label && $set[1] ne 'auto'){
                               $idx[$j] = $i;
                               last
                            }
                            $j++
                        }
                    }
                }
                foreach (@data){
                    my @row = @{$_};
                    my @insert = @idx;
                    for(my $i=0; $i<@idx; $i++){
                       $insert[$i] = $row[$idx[$i]] if $idx[$i] < @row
                    }
                    $dbsTblInsert->execute(@insert)
                }
                ###
            }
         }
       }
    }
    $db->disconnect();
    $parser->data()->{$property} = [$self];
}

sub processTable ($db, $node) {
    unless (exists $tables{$node->{name}}) {
        my $sqlCreateTable  = "CREATE TABLE ".$node->{name}."(";
        my $sqlInsert  = "INSERT INTO ".$node->{name}." ("; my $sqlVals;
           my @columns = @{$node->find('cols/@@')};
           warn "Not found any 'cols/@@' path elements for CNF node :". $node->name() if not @columns;
           my $primary_key;
           for(my $i=0;$i<@columns;$i++){
             my $col = $columns[$i];
             my ($n,$v) = ($col->val() =~ /\s*(.*?)\s+(.*)/);
             if($v =~ /^auto/){
                if( $isSQLite ){
                    $v = "integer primary key autoincrement"                
                }else{
                    $v = "INT UNIQUE GENERATED ALWAYS AS IDENTITY";
                    $primary_key = $n;
                }
                splice(@columns,$i--,1);
             }else{
                if($v =~ /^datetime/){
                    if( $isSQLite ){
                        $v = "TEXT"
                    }else{
                        $v = "TIMESTAMP";                    
                    }
                }else{
                    $v =~ s/\s*$//;
                }
                $sqlInsert .= "$n,"; $sqlVals .= "?,";
                $columns[$i] = [$n,$v];
             }
             $sqlCreateTable .= "$n $v,\n";
           }
           $sqlCreateTable .= "PRIMARY KEY($primary_key)" if $primary_key;
           $sqlCreateTable =~ s/,$//;  $sqlInsert =~ s/,$//;  $sqlVals =~ s/,$//;
           $sqlCreateTable .= ");";    $sqlInsert  .= ") VALUES ($sqlVals);";
           $node->{sqlCreateTable} = $sqlCreateTable;
           $node->{sqlInsert} = $sqlInsert;
           $node->{_MAPPING_} = \@columns;
           $tables{$node->{name}} = $node;
        $db->do($sqlCreateTable);
        return 1;
    }
    return 0;
}

###
# Process config data to contain expected fields and data.
###
sub processData ($parser, $property) {
    my @DATA = $parser->data()->{$property};
    my (@SPEC,@HDR);
#
# The sometime unwanted side of perl is that when dereferencing arrays,
# modification only is visible withing the scope of the block.
# Following processes and creates new references on modified data.
# And is the reason why it might look ugly or has some unecessary relooping.
#
    for my $did (0 .. $#DATA){
        my @entry = @{$DATA[$did]};
        my $ID_Spec_Size = 0;
        my $mod = 0;
        #
        # Build data type specs, obtain header mapping and cleanup header label row for the columns,
        # if present.
        foreach (@entry){
            my @row = @$_;
            $ID_Spec_Size = scalar @row;
            for my $i (0..$ID_Spec_Size-1){
                if($row[$i] =~ /^#/){ # Numberic
                    $SPEC[$i] = 1;
                }
                elsif($row[$i] =~ /^@/){ # DateTime
                    $SPEC[$i] = 2;
                }
                else{
                    $SPEC[$i] = 3;  # Text
                }
            }
            if($row[0]){
                @HDR = shift @entry;
                $DATA[$did]=\@entry;
                last
            }
        }
        for my $eid (0 .. $#entry){
            my @row = @{$entry[$eid]};
            if ($ID_Spec_Size){
                # If zero it is presumed ID field, corresponding to row number + 1 as our assumed autonumber max count.
                if(defined $row[0] && $row[0] == 0){
                    my $size = @row;
                    $size = length(''.$size);
                    $row[0] = zero_prefix($size,$eid+1);
                    $mod = 1
                }
                if(@row!=$ID_Spec_Size){
                    warn "Row data[$eid] doesn't match expect column count: $ID_Spec_Size\n @row";
                }else{
                    for my $i (1..$ID_Spec_Size-1){
                        if(not matchType($SPEC[$i], $row[$i])){
                           warn "Row in row[$i]='$row[$i]' doesn't match expect data type, contents: @row";
                        }
                        elsif($SPEC[$i]==2){
                               my $dts = $row[$i];
                               my $dt  = UnixDate(ParseDateString($dts), "%Y-%m-%d %T");
                               if($dt){ $row[$i] = $dt; $mod = 1 }else{
                                  warn "Row in row[$i]='$dts' has imporper date format, contents: @row";
                               }
                        }
                    }
                }
                $entry[$eid]=\@row if $mod; #<-- re-reference as we changed the row. Something hard to understand.
            }
        }
        $DATA[$did]=\@entry if $mod;
    }
    return [\@SPEC, \@HDR, \@DATA];
}
sub zero_prefix ($times, $val) {
    return '0'x$times.$val;
}
sub matchType($type, $val, @rows) {
    if   ($type==1 && looks_like_number($val)){return 1}
    elsif($type==2){
          if($val=~/\d*\/\d*\/\d*/){return 1}
          else{
               return 1;
          }
    }
    elsif($type==3){return 1}
    return 0;
}

1;