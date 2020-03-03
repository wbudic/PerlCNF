#!/usr/bin/perl -w
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
package Settings;

use strict;
use warnings;
use Switch;
use Exception::Class ('SettingsException');
use Syntax::Keyword::Try;

use DBI;

#This is the default developer release key, replace on istallation. As it is not secure.
use constant CIPHER_KEY => '95d7a85ba891da';

#DEFAULT SETTINGS HERE!
our $RELEASE_VER  = '1.8';
our $TIME_ZONE    = 'Australia/Sydney';
our $LANGUAGE     = 'English';
our $PRC_WIDTH    = '60';
our $LOG_PATH     = '../../dbLifeLog/';
our $SESSN_EXPR   = '+30m';
our $DATE_UNI     = '0';
our $AUTHORITY    = '';
our $IMG_W_H      = '210x120';
our $REC_LIMIT    = 25;
our $AUTO_WRD_LMT = 1000;
our $VIEW_ALL_LMT = 1000;
our $FRAME_SIZE   = 0;
our $RTF_SIZE     = 0;
our $THEME        = 'Standard';
our $TRACK_LOGINS = 1;
our $KEEP_EXCS    = 0;

#Annons here, variables that could be overiden in  code or database, per need.
my %anons = ();

### Page specific settings Here
our $TH_CSS        = 'main.css';
our $BGCOL         = '#c8fff8';
#Set to 1 to get debug help. Switch off with 0.
our $DEBUG         = 1;
#END OF SETTINGS

### Private Settings sofar (id -> name : def.value):
#200 -> '^REL_RENUM' : this.$RELEASE_VER (Used in login_ctr.cgi)
#201 -> '^EXCLUDES'  : 0 (Used in main.cgi)

sub anons {return sort keys %anons}
#Check call with defined(Settings::anon('my_anon'))
sub anon {my $n=shift; return $anons{$n}}

sub release        {return $RELEASE_VER}
sub logPath        {return $LOG_PATH}
sub theme          {return $THEME}
sub language       {return $LANGUAGE}
sub timezone       {return $TIME_ZONE}
sub sessionExprs   {return $SESSN_EXPR}
sub imgWidthHeight {return $IMG_W_H}
sub pagePrcWidth   {return $PRC_WIDTH}
sub frameSize      {return $FRAME_SIZE}
sub universalDate  {return $DATE_UNI;}
sub recordLimit    {return $REC_LIMIT}
sub autoWordLimit  {return $AUTO_WRD_LMT}
sub viewAllLimit   {return $VIEW_ALL_LMT}
sub trackLogins    {return $TRACK_LOGINS}
sub windowRTFSize  {return $RTF_SIZE}
sub keepExcludes   {return $KEEP_EXCS}
sub bgcol          {return $BGCOL}
sub css            {return $TH_CSS}
sub debug          {my $ret=shift; if($ret){$DEBUG = $ret;}; return $DEBUG;}

sub createCONFIGStmt {
return qq(
    CREATE TABLE CONFIG(
        ID TINY             PRIMARY KEY NOT NULL,
        NAME VCHAR(16)      UNIQUE,
        VALUE VCHAR(28),
        DESCRIPTION VCHAR(128)
    );
    CREATE INDEX idx_config_name ON CONFIG (NAME);
)}
sub createCATStmt {
return qq(
    CREATE TABLE CAT(
        ID TINY             PRIMARY KEY NOT NULL,
        NAME                VCHAR(16),
        DESCRIPTION         VCHAR(64)
    );
    CREATE INDEX idx_cat_name ON CAT (NAME);
)}
sub createLOGStmt {
return qq(
    CREATE TABLE LOG (
        ID_CAT TINY        NOT NULL,
        ID_RTF INTEGER     DEFAULT 0,
        DATE   DATETIME    NOT NULL,
        LOG    VCHAR (128) NOT NULL,
        AMOUNT INTEGER,
        AFLAG TINY         DEFAULT 0,
        STICKY BOOL        DEFAULT 0
    );
)}
sub createVW_LOGStmt {
return qq(
CREATE VIEW VW_LOG AS
    SELECT rowid as ID,*, (select count(rowid) from LOG as recount where a.rowid >= recount.rowid) as PID
        FROM LOG as a ORDER BY Date(DATE) DESC;'
)}
sub createAUTHStmt {
return qq(
    CREATE TABLE AUTH(
        ALIAS varchar(20)   PRIMARY KEY,
        PASSW TEXT,
        EMAIL               varchar(44),
        ACTION TINY
    ) WITHOUT ROWID;
    CREATE INDEX idx_auth_name_passw ON AUTH (ALIAS, PASSW);
)}
sub createNOTEStmt {
    return qq(CREATE TABLE NOTES (LID INTEGER PRIMARY KEY NOT NULL, DOC TEXT);)
}
sub createLOGCATSREFStmt {
return qq(
    CREATE TABLE LOGCATSREF (
        LID INTEGER NOT NULL,
        CID TINY NOT NULL,
    FOREIGN KEY (LID) REFERENCES LOG(ID),
    FOREIGN KEY(CID) REFERENCES CAT(ID)
    );
)}

sub getConfiguration {
    my ($db, $hsh) = @_;
    try {
        my $st = $db->prepare("SELECT ID, NAME, VALUE FROM CONFIG;");
           $st->execute();
        while ( my @r = $st->fetchrow_array() ){
                switch ( $r[1] ) {
                case "RELEASE_VER"  { $RELEASE_VER  = $r[2];}
                case "TIME_ZONE"    { $TIME_ZONE    = $r[2];}
                case "PRC_WIDTH"    { $PRC_WIDTH    = $r[2];}
                case "SESSN_EXPR"   { $SESSN_EXPR   = $r[2];}
                case "DATE_UNI"     { $DATE_UNI     = $r[2];}
                case "LANGUAGE"     { $LANGUAGE     = $r[2];}
                case "LOG_PATH"     {} #ommited and code static can't change for now.
                case "IMG_W_H"      { $IMG_W_H      = $r[2];}
                case "REC_LIMIT"    { $REC_LIMIT    = $r[2];}
                case "AUTO_WRD_LMT" { $AUTO_WRD_LMT = $r[2];}
                case "VIEW_ALL_LMT" { $VIEW_ALL_LMT = $r[2];}
                case "FRAME_SIZE"   { $FRAME_SIZE   = $r[2];}
                case "RTF_SIZE"     { $RTF_SIZE     = $r[2];}
                case "THEME"        { $THEME        = $r[2];}
                case "DEBUG"        { $DEBUG        = $r[2];}
                case "KEEP_EXCS"    { $KEEP_EXCS    = $r[2];}
                case "TRACK_LOGINS" { $TRACK_LOGINS = $r[2];}
                else                { $anons{$r[1]} = $r[2];}
                }
        }
        #Anons are murky grounds. -- @bud
        if($hsh){
            my $stIns = $db->prepare("INSERT INTO CONFIG (ID, NAME, VALUE, DESCRIPTION) VALUES(?,?,?,?)");
            foreach my $key (keys %{$hsh}){
                if(index($key,'$')!=0){#per spec. anons are not prefixed with an '$' as signifier.
                    my $val = %{$hsh}{$key};
                    my $existing = $anons{$key};
                    #exists? Overwrite for $self config but not in DB! (dynamic code base set anon)
                    $anons{$key} = $val;
                    if(not defined $existing){
                        #Make it now config global. Note another source latter calling this subroutine
                        #can overwrite this, but not in the database. Where it is now set by the following.
                        #Find free ID.
                        my @res = selectRecords($db,"SELECT MAX(ID) FROM CONFIG;")->fetchrow_array();
                        #ID's under 300 are reserved, for constants.
                        my $id = $res[0]+1;
                        while($id<300){ $id += ($id*1.61803398875); }#Golden ratio step it to best next available.
                        $stIns->execute(int($id), $key, $val, "Anonymous application setting.");
                    }
                }
            }
        }
    }
    catch {
        SettingsException->throw(error=>$@, show_trace=>$DEBUG);
    };
}


sub getTheme {

        switch ($THEME){
            case "Sun"   { $BGCOL = '#D4AF37'; $TH_CSS = "main_sun.css"; }
            case "Moon"  { $BGCOL = '#000000'; $TH_CSS = "main_moon.css"; }
            case "Earth" { $BGCOL = '#26ac0c'; $TH_CSS = "main_earth.css";} # Used to be $BGCOL = '#26be54';
            else{
                # Standard;
                $BGCOL    = '#c8fff8';
                $TH_CSS   = 'main.css';
            }
        }

}



#From v.1.8 Changed
sub renumerate {
    my $db = shift;
    #Renumerate Log! Copy into temp. table.
    my $sql;
    selectRecords($db, 'CREATE TABLE life_log_temp_table AS SELECT * FROM LOG;');
    #update  notes table with new log id only for reference sake.
    my $st = selectRecords($db, 'SELECT rowid, DATE FROM LOG WHERE ID_RTF > 0 ORDER BY DATE;');
    while(my @row =$st->fetchrow_array()) {
        my $sql_date = $row[1];
        #$sql_date =~ s/T/ /;
        $sql_date = DateTime::Format::SQLite->parse_datetime($sql_date);
        $sql = "SELECT rowid, DATE FROM life_log_temp_table WHERE ID_RTF > 0 AND DATE = '".$sql_date."';";
        my @new  = selectRecords($db, $sql)->fetchrow_array();
        if(scalar @new > 0){
             try{#can fail here, for various reasons.
                $sql="UPDATE NOTES SET LID =". $new[0]." WHERE LID==".$row[0].";";
                $db->do($sql);
             }
             catch{
                 SettingsException->throw(error=>"Database error encountered. sql->$sql", show_trace=>$DEBUG);
             };
        }
    }

    # Delete any possible orphaned Notes records.
    $st = selectRecords($db, "SELECT LID, LOG.rowid from NOTES LEFT JOIN LOG ON
                                    NOTES.LID = LOG.rowid WHERE LOG.rowid is NULL;");
    while($st->fetchrow_array()) {
        $db->do("DELETE FROM NOTES WHERE LID=".$_[0].";")
    }
    $db->do('DROP TABLE LOG;');
    $db->do(&createLOGStmt);
    $db->do('INSERT INTO LOG (ID_CAT, ID_RTF, DATE, LOG, AMOUNT,AFLAG,STICKY)
                       SELECT ID_CAT, ID_RTF, DATE, LOG, AMOUNT, AFLAG, STICKY FROM life_log_temp_table ORDER by DATE;');
    $db->do('DROP TABLE life_log_temp_table;');
}

sub selectRecords {
    my ($db, $sql) = @_;
    if(scalar(@_) < 2){
                SettingsException->throw("ERROR Argument number is wrong->db is:$db\n", show_trace=>$DEBUG);
    }
    try{
                my $pst	= $db->prepare($sql) or SettingsException->throw("<p>ERROR with->$sql</p>", show_trace=>$DEBUG);
                $pst->execute();
                return 0 if(!$pst);
                return $pst;
    }catch{
                SettingsException->throw(error=>"Database error encountered. Settings::selectRecords[$sql]", show_trace=>$DEBUG);
    };
}

sub getTableColumnNames {
        my ($db, $table_name) = @_;
        if(scalar(@_) < 2){
                SettingsException->throw("ERROR Argument number is wrong->db is:$db\n", show_trace=>$DEBUG);
        }
        try{
                my $pst = selectRecords($db, "SELECT name FROM PRAGMA_table_info('$table_name');");
                my @ret = ();
                while(my @r = $pst->fetchrow_array()){
                    push @ret, $r[0];
                }
                return \@ret;
        }catch{
                SettingsException->throw(error=>"Database error encountered.", show_trace=>$DEBUG);
        }
}

sub printDebugHTML {
    my $msg = shift;
    print qq(<!-- $msg -->);
}

sub toLog {
    my ($db,$log,$cat) = @_;
    my $stamp = getCurrentSQLTimeStamp();
        if(!$cat){
            my @arr = selectRecords($db,"SELECT ID FROM CAT WHERE NAME LIKE 'System Log' or NAME LIKE 'System';")->fetchrow_array();
            if(@arr){
                $cat = $arr[0];
            }
            else{
                $cat = 6;
            }
        }
       $log =~ s/'/''/g;
       $db->do("INSERT INTO LOG (ID_CAT, DATE, LOG) VALUES($cat,'$stamp', \"$log\");");
}

sub countRecordsIn {
    my ($db,$name) = @_;
     if(scalar(@_) < 2){
        SettingsException->throw("ERROR Argument number is wrong.name:$name\n", show_trace=>$DEBUG);
    }
    my $ret = selectRecords($db, "SELECT count(ID) FROM $name;");
    if($ret){
       $ret ->fetchrow_array();
       $ret = 0 if not $ret;
    }
    return $ret;
}

sub getCurrentSQLTimeStamp {

     my $dt = DateTime->from_epoch(epoch => time(), time_zone=> $TIME_ZONE);
     # 20200225  Found that SQLite->format_datetime, changes internally to UTC timezone, which is wrong.
     # Strange that this format_datetime will work from time to time, during day and some dates. (A Pitfall)
    #return DateTime::Format::SQLite->format_datetime($dt);
    return join ' ', $dt->ymd('-'), $dt->hms(':');
}

sub removeOldSessions {
    opendir(DIR, $LOG_PATH);
    my @files = grep(/cgisess_*/,readdir(DIR));
    closedir(DIR);
    my $now = time - (24 * 60 * 60);
    foreach my $file (@files) {
        my $mod = (stat("$LOG_PATH/$file"))[9];
        if($mod<$now){
            unlink "$LOG_PATH/$file";
        }
    }
}



sub obtainProperty {
    my($db, $name) = @_;
    SettingsException->throw("Invalid use of subroutine obtainProperty($db, $name)", show_trace=>$DEBUG) if(!$db || !$name);
    my $dbs = selectRecords($db, "SELECT ID, VALUE FROM CONFIG WHERE NAME IS '$name';");
    my @row = $dbs->fetchrow_array();
    if(scalar @row > 0){
       return $row[1];
    }
    else{
       return 0;
    }
}

sub configProperty {
    my($db, $id, $name, $value) = @_;
    $id = '0' if not $id;
    if($db eq undef || $value eq undef){
        SettingsException->throw(
            error => "ERROR Invalid number of arguments in call -> Settings::configProperty('$db',$id,'$name','$value')\n",  show_trace=>$DEBUG
            );
    };
    if($name eq undef && $id){

        my $sql = "UPDATE CONFIG SET VALUE='".$value."' WHERE ID=".$id.";";
        try{
            $db->do($sql);
        }
        catch{

            SettingsException->throw(
                error => "ERROR with $sql -> Settings::configProperty('$db',$id,'$name','$value')\n",
                show_trace=>$DEBUG
                );
        }
    }
    else{
        my $dbs = selectRecords($db, "SELECT ID, NAME FROM CONFIG WHERE NAME IS '$name';");
        if($dbs->fetchrow_array()){
            $db->do("UPDATE CONFIG SET VALUE = '$value' WHERE NAME IS '$name';");
        }
        else{
            my $sql = "INSERT INTO CONFIG (ID, NAME, VALUE) VALUES ($id, '$name', '$value');";
            try{
                $db->do($sql);
            }
            catch{

                SettingsException->throw(
                    error => "ERROR $@ with $sql -> Settings::configProperty('$db',$id,'$name','$value')\n",
                    show_trace=>$DEBUG
                    );
            }
        }
    }
}


1;