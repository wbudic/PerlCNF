#!/usr/bin/perl
#
# Web interaction, reusable tri state of configuration concerns, set of utilities. 
#
# Programed by: Will Budic
# Open Source License -> https://choosealicense.com/licenses/isc/
#
package Settings;
use v5.30; #use diagnostics;
use warnings; no warnings 'experimental';
use strict;
use CGI::Carp qw(fatalsToBrowser set_message);
use Exception::Class ('SettingsException','LifeLogException','SettingsLimitSizeException');
use Syntax::Keyword::Try;

use CGI;
use CGI::Session '-ip_match';
use DateTime;
use DateTime::Format::SQLite;
use DateTime::Duration;
use DBI;
use Scalar::Util qw(looks_like_number);
BEGIN {
   sub handle_errors {
      my $msg = shift;
      print "<html><body><h2>LifeLog Server Error</h2>";
      print "<pre>@[$ENV{PWD}].Error: $msg</pre></body></html>"; return
 
  }
  set_message(\&handle_errors);
}

# This is the default developer release key, replace on istallation. As it is not secure.
use constant CIPHER_KEY             => '95d7a85ba891da';
use constant CIPHER_PADDING         => 'fe0a2b6a83e81f13a2d76ab104763773310df6b0a01c7cf9807b4b0ce2a02';

# Default VIEW for all pages, it lists and sorts on all logs, super fast server side.
use constant VW_LOG                 => 'VW_LOG';

# Optional instructional VIEW from config file replacing VW_LOG. 
# Filtering out by category ID certain specified entries.
use constant VW_LOG_WITH_EXCLUDES   => 'VW_LOG_WITH_EXCLUDES';

# Optional instructional VIEW from config directly overriding the 
# where clause for data being delivered for pages.
# This view will always return all last 24 hour entered log entries.
# This view AND's by extending on VW_LOG_WITH_EXCLUDES, if is also set, which is something to be aware.
# Otherwise, similar just replaces the VW_LOG to deliver pages.
#
use constant VW_LOG_OVERRIDE_WHERE  => 'VW_LOG_OVR_WHERE';

use constant META => '^CONFIG_META';


# DEFAULT SETTINGS HERE! These settings kick in if not found in config file. i.e. wrong config file or has been altered, things got missing.
our $RELEASE_VER  = '2.5';
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
our $AUTO_WRD_LEN = 17; #Autocompletion word length limit. Internal.
our $AUTO_LOGOFF  = 0;
our $VIEW_ALL_LMT = 1000;
our $DISP_ALL     = 1;
our $FRAME_SIZE   = 0;
our $RTF_SIZE     = 0;
our $THEME        = 'Standard';
our $TRANSPARENCY = 1;
our $TRANSIMAGE   = 'wsrc/images/std-log-lbl-bck.png';
our $TRACK_LOGINS = 1;
our $KEEP_EXCS    = 0;
our $COMPRESS_ENC = 0; #HTTP Compressed encoding.
our $DBI_SOURCE   = "DBI:SQLite:";
our $DBI_LVAR_SZ  = 1024;
our $CURR_SYMBOL  = '$';

my ($cgi, $sss, $sid, $alias, $pass, $dbname, $pub);
our $DSN;
our $DBFILE;
our $IS_PG_DB     = 0;
#Annons here, variables that could be overriden in  code or in database, per need and will.
our %anons = ();
our %tz_map;

### Page specific settings Here
our $TH_CSS        = 'main.css';
our $JS            = 'main.js';
our $BGCOL         = '#c8fff8';
#Set to 1 to get debug help. Switch off with 0.
our $DEBUG         = 1;
#END OF SETTINGS

### Private Settings sofar (id -> name : def.value):
#200 -> '^REL_RENUM' : this.$RELEASE_VER (Used in login_ctr.cgi)
#201 -> '^EXCLUDES'  : 0 (Used in main.cgi)

our $SQL_PUB = undef;
our $TIME_ZONE_MAP ="";

#The all purpose '$S_' class get/setter variable, we do better with less my new variable assignments.
our $S_ =""; 
#
sub anons {keys %anons}
#Check call with defined(Settings::anon('my_anon'))
sub anon {$S_=shift; $S_ = $anons{$S_} if $S_;$S_}
sub anonsSet {my $a = shift;%anons=%{$a}}

sub release        {$RELEASE_VER}
sub logPath        {$LOG_PATH} # <-@2021-08-15 something was calling as setter, can't replicate. On reset of categories in config.cgi.
sub logPathSet     {$S_ = shift;$LOG_PATH = $S_ if $S_;return $LOG_PATH}#<-has now setter method nothing it is actually calling.
sub timezone       {$TIME_ZONE}
sub transparent    {$TRANSPARENCY}
sub transimage     {$TRANSIMAGE}
sub language       {$LANGUAGE}
sub sessionExprs   {$SESSN_EXPR}
sub imgWidthHeight {$IMG_W_H}
sub pagePrcWidth   {$PRC_WIDTH}
sub frameSize      {$FRAME_SIZE}
sub universalDate  {$DATE_UNI}
sub recordLimit    {$REC_LIMIT}
sub autoWordLimit  {$AUTO_WRD_LMT}
sub autoWordLength {$AUTO_WRD_LEN}
sub autoLogoff     {$AUTO_LOGOFF}
sub viewAllLimit   {$VIEW_ALL_LMT}
sub displayAll     {$DISP_ALL}
sub trackLogins    {$TRACK_LOGINS}
sub windowRTFSize  {$RTF_SIZE}
sub keepExcludes   {$KEEP_EXCS}
sub currenySymbol  {$CURR_SYMBOL}
sub bgcol          {$BGCOL}
sub css            {$TH_CSS}
sub js             {$JS}
sub compressPage   {$COMPRESS_ENC}
sub debug          {$S_ = shift; $DEBUG = $S_ if $S_; $DEBUG}
sub dbSrc          {$S_= shift; if($S_) {$DBI_SOURCE=$S_; $IS_PG_DB = 1 if(index (uc $S_, 'DBI:PG') ==0)}  
                    $DBI_SOURCE}
sub dbVLSZ         {$S_ = shift; if(!$S_){$S_ = $DBI_LVAR_SZ}else{$S_=128 if($S_<128);$DBI_LVAR_SZ=$S_}}
sub dbFile         {$S_ = shift; $DBFILE = $S_ if $S_; $DBFILE}
sub dbName         {$S_ = shift; $dbname = $S_ if $S_; $dbname}
sub dsn            {$DSN}
sub isProgressDB   {$IS_PG_DB} sub resetToDefaultDriver {$IS_PG_DB=0}
sub sqlPubors      {$SQL_PUB}

sub cgi     {$cgi}
sub session {$sss}
sub sid     {$sid}
sub alias   {$alias}
sub pass    {$pass}
sub pub     {$pub}

sub trim {my $r=shift; $r=~s/^\s+|\s+$//g;  $r}
# The following has to be called from an CGI seesions container that provides parameters.
sub fetchDBSettings {
try {
    $CGI::POST_MAX = 1024 * 1024 * 5;  # max 5GB file post size limit.
    $cgi     = $cgi = CGI->new();
    $sss     = shift; #shift will only and should, ONLY happen for test scripts.
    $sss     = CGI::Session->new("driver:File", $cgi, {Directory=>$LOG_PATH, SameSite=>'Lax'}) if !$sss;
    $sid     = $sss->id();    
    $alias   = $sss->param('alias');
    $pass    = $sss->param('passw');
    $pub     = $cgi->param('pub');$pub = $sss->param('pub') if not $pub; #maybe test script session set in $sss.
    $dbname  = $sss->param('database'); $dbname = $alias if(!$dbname);

    ##From here we have data source set, currently Progress DB SQL and SQLite SQL compatible.
    dbSrc($sss->param('db_source'));

    if($pub){#we override session to obtain pub(alias)/pass from file main config.
        open(my $fh, '<', logPath().'main.cnf') or LifeLogException->throw("Can't open main.cnf: $!");        
        while (my $line = <$fh>) {
                  chomp $line;
                  my $v = parseAutonom('PUBLIC_LOGIN',$line);
                  if($v){my @cre = split '/', $v; 
                           $alias = $cre[0];                           
                           $pass = uc crypt $cre[1], hex Settings->CIPHER_KEY;
                  }                    
                  $v = parseAutonom('PUBLIC_CATS',$line);
                  if($v){my @cats= split(',',$v);
                        foreach(@cats){
                            $SQL_PUB .= "ID_CAT=".trim($_)." OR ";
                        }
                        $SQL_PUB =~ s/\s+OR\s+$//;
                   }elsif($line =~ /<<PLUGINS</){        
                        $S_ = substr($line, 10);               
                        while ($line = <$fh>) {
                            chomp $line;
                            last if($line =~ />$/);
                            $S_ .= $line . "\n";
                        }
                        anonsSet('PLUGINS', $S_);
                        next;
                    }elsif($line =~ /'<<'.META.'<'/p){
                        anonsSet(META, 1)
                    }
                   last if parseAutonom(META, $line);
        }
        close $fh; 
        if(!$SQL_PUB&&$pub ne 'test'){$alias=undef}       
    }
    if(!$alias){
        print $cgi->redirect("login_ctr.cgi?CGISESSID=$sid");
        exit;
    }    
    my $ret  = connectDB($dbname, $alias, $pass);
    getConfiguration($ret);    
    setupTheme();
    $sss->expire($SESSN_EXPR);
    return $ret;
}catch{    
    SettingsException->throw(error=>"DSN<$DSN>".$@, show_trace=>$DEBUG);
    exit;
}
}

sub today {
    my $ret = setTimezone();
    return $ret;
}

#Call after getConfig subroutine. Returns DateTime->now() set to timezone.
sub setTimezone {    
    my $to  = shift; #optional for testing purposes.    
    my $ret = DateTime->now();
    if(!$anons{'auto_set_timezone'}){
       if($TIME_ZONE_MAP){
            if(!%tz_map){
                %tz_map=(); chomp($TIME_ZONE_MAP);
                foreach (split('\n',$TIME_ZONE_MAP)){
                    my @p = split('=', $_);
                    $tz_map{trim($p[0])} = trim($p[1]);
                }
            }
            my $try = $tz_map{$TIME_ZONE};
               $try = $tz_map{$to} if(!$try && $to);
            if($try){
                $TIME_ZONE = $try; #translated to mapped lib. provided zone.
                $ret -> set_time_zone($try);
            }
            else{
                try{#maybe current setting is valid and the actual one?
                    $ret -> set_time_zone($TIME_ZONE); 
                }catch{
                 SettingsException->throw(error=>"Zone not mapped:$TIME_ZONE\n<b>Available zones:</b>\n$TIME_ZONE_MAP\n", show_trace=>$DEBUG);
                }
            }
        }
    }else{
        $ret -> set_time_zone($TIME_ZONE);
    }
    return $ret;
}

sub createCONFIGStmt {
    if($IS_PG_DB){return qq(
        CREATE TABLE CONFIG(
            ID INT NOT NULL UNIQUE GENERATED BY DEFAULT AS IDENTITY ( INCREMENT 1 START 1 MINVALUE 1 MAXVALUE 2147483647 CACHE 1 ),
            NAME VARCHAR(28)  UNIQUE,
            VALUE             VARCHAR(128),
            DESCRIPTION       VARCHAR(128),
            PRIMARY KEY(ID)
        );
        CREATE INDEX idx_config_name ON CONFIG (NAME);
    )}
return qq(
    CREATE TABLE CONFIG(
        ID INT  PRIMARY KEY NOT NULL,
        NAME VCHAR(16)  UNIQUE,
        VALUE VCHAR(128),
        DESCRIPTION VCHAR(128)
    );
    CREATE INDEX idx_config_name ON CONFIG (NAME);
)}
sub createCATStmt {
    if($IS_PG_DB){
        return qq(    
        CREATE TABLE CAT(
            ID INT             GENERATED BY DEFAULT AS IDENTITY,
            NAME               VARCHAR(16),
            DESCRIPTION        VARCHAR(225),
            PRIMARY KEY(ID)
        );
        CREATE INDEX idx_cat_name ON CAT (NAME);
    )}
return qq(    
    CREATE TABLE CAT(
        ID INT             PRIMARY KEY NOT NULL,
        NAME               VARCHAR(16),
        DESCRIPTION        VARCHAR(225)
    );
    CREATE INDEX idx_cat_name ON CAT (NAME);
)}
sub createLOGStmt { 
#ID_RTF in v.2.0 and lower is not an id, changed to byte from v.2.1.
if($IS_PG_DB){ 
        return qq(
        CREATE TABLE LOG (
            ID INT UNIQUE GENERATED ALWAYS AS IDENTITY,
            ID_CAT INT        NOT NULL,            
            DATE TIMESTAMP    NOT NULL,
            LOG VARCHAR ($DBI_LVAR_SZ) NOT NULL,
            RTF    SMALLINT   DEFAULT 0,
            AMOUNT MONEY,
            AFLAG  INT        DEFAULT 0,
            STICKY BOOL       DEFAULT FALSE,
            PRIMARY KEY(ID)
        );)} 

  return qq(
    CREATE TABLE LOG (
        ID_CAT INT        NOT NULL,        
        DATE DATETIME     NOT NULL,
        LOG VARCHAR ($DBI_LVAR_SZ) NOT NULL,
        RTF    BYTE       DEFAULT 0,
        AMOUNT DOUBLE,
        AFLAG  INT        DEFAULT 0,
        STICKY BOOL       DEFAULT 0
    );
)}

sub selLogIDCount {
    if($IS_PG_DB){return 'select count(ID) from LOG;'}
    return 'select count(rowid) from LOG;'
}

sub selStartOfYear {
    if($IS_PG_DB){return "date>= date_trunc('year', now())"}
    return "date>=date('now','start of year')"
}

sub createViewLOGStmt {
    my($name,$where) = @_;
    $name = VW_LOG  if not $name;
    if($IS_PG_DB){
    return qq(
        CREATE VIEW public.$name AS
        SELECT *, (select count(ID) from LOG as recount where a.id >= recount.id) as PID
            FROM LOG as a $where ORDER BY DATE DESC;
        );
    } 
return qq(
CREATE VIEW $name AS
    SELECT rowid as ID,*, (select count(rowid) from LOG as recount where a.rowid >= recount.rowid) as PID
        FROM LOG as a $where ORDER BY Date(DATE) DESC, Time(DATE) DESC;
)}
sub createAUTHStmt {
    if($IS_PG_DB){
    return qq(
        CREATE TABLE AUTH(
            ALIAS varchar(20)   PRIMARY KEY,
            PASSW TEXT,
            EMAIL               varchar(44),
            ACTION INT
        );
        CREATE INDEX idx_auth_name_passw ON AUTH (ALIAS, PASSW);      
    )}
return qq(
    CREATE TABLE AUTH(
        ALIAS varchar(20)   PRIMARY KEY,
        PASSW TEXT,
        EMAIL               varchar(44),
        ACTION INT
    ) WITHOUT ROWID;
    CREATE INDEX idx_auth_name_passw ON AUTH (ALIAS, PASSW);
)}
sub createNOTEStmt {
    if($IS_PG_DB){
      # return qq(CREATE TABLE NOTES (LID INT PRIMARY KEY NOT NULL, DOC jsonb);)
      return qq(CREATE TABLE NOTES (LID INT PRIMARY KEY NOT NULL, DOC bytea);) 
    }
    return qq(CREATE TABLE NOTES (LID INT PRIMARY KEY NOT NULL, DOC BLOB);)
}
sub createLOGCATSREFStmt {
if($IS_PG_DB){
return qq(
    CREATE TABLE LOGCATSREF (
        LID INT NOT NULL,
        CID INT NOT NULL,
		primary key(LID)		
    );    
)}
# CONSTRAINT fk_log  FOREIGN KEY(LID) REFERENCES LOG(ID) ON DELETE CASCADE, 
# CONSTRAINT fk_cats FOREIGN KEY(CID) REFERENCES CAT(ID) ON DELETE CASCADE 
return qq(
    CREATE TABLE LOGCATSREF (
        LID INT NOT NULL,
        CID INT NOT NULL,
    FOREIGN KEY (LID) REFERENCES LOG(ID),
    FOREIGN KEY (CID) REFERENCES CAT(ID)
    );
)}
#Selects the actual database set configuration for the application, these kick in overwritting those from the config file.
sub getConfiguration { my ($db, $hsh) = @_;
    my @r; my $ftzmap = 'tz.map';    
    try {
        my $st = $db->prepare("SELECT ID, NAME, VALUE FROM CONFIG;");  $st->execute();
        while( @r = $st->fetchrow_array() ){
               given ( $r[1] ) {
                when ("RELEASE_VER") {$RELEASE_VER  = $r[2]}
                when ("TIME_ZONE")   {$TIME_ZONE    = $r[2]}
                when ("PRC_WIDTH")   {$PRC_WIDTH    = $r[2]}
                when ("SESSN_EXPR")  {$SESSN_EXPR   = timeFormatSessionValue($r[2])}
                when ("DATE_UNI")    {$DATE_UNI     = $r[2]}
                when ("LANGUAGE")    {$LANGUAGE     = $r[2]}
                when ("LOG_PATH")    {} # Ommited and code static can't change for now.
                when ("IMG_W_H")     {$IMG_W_H      = $r[2]}
                when ("REC_LIMIT")   {$REC_LIMIT    = $r[2]}
                when ("AUTO_WRD_LMT"){$AUTO_WRD_LMT = $r[2]}
                when ("AUTO_LOGOFF") {$AUTO_LOGOFF  = $r[2]}
                when ("VIEW_ALL_LMT"){$VIEW_ALL_LMT = $r[2]}
                when ("DISP_ALL")    {$DISP_ALL     = $r[2]}
                when ("FRAME_SIZE")  {$FRAME_SIZE   = $r[2]}
                when ("RTF_SIZE")    {$RTF_SIZE     = $r[2]}
                when ("THEME")       {$THEME        = $r[2]}
                when ("TRANSPARENCY"){$TRANSPARENCY = $r[2]}
                when ("TRANSIMAGE")  {$TRANSIMAGE   = $r[2]}
                when ("DEBUG")       {$DEBUG        = $r[2]}
                when ("KEEP_EXCS")   {$KEEP_EXCS    = $r[2]}
                when ("TRACK_LOGINS"){$TRACK_LOGINS = $r[2]}
                when ("COMPRESS_ENC"){$COMPRESS_ENC = $r[2]}
                when ("CURR_SYMBOL") {$CURR_SYMBOL  = $r[2]}
                default              {$anons{$r[1]} = $r[2]}
                }
        }
        #Anons are murky grounds. -- @bud        
        if($hsh){
            my %m = %{$hsh};
            $TIME_ZONE_MAP = $m{'TIME_ZONE_MAP'}; #This can be a large mapping we file it to tz.map, rather then keep in db.
            delete($m{'TIME_ZONE_MAP'});
            if($TIME_ZONE_MAP && !(-e $ftzmap)) {
                open(my $fh, '>', $ftzmap) or die "Can't write to '$ftzmap': $!";
                print $fh $TIME_ZONE_MAP;
                close $fh;
            }#else{
            #     SettingsException -> throw(error=>"Missing anon TIME_ZONE_MAP! $TIME_ZONE_MAP ",show_trace=>1);
            # }
            my $stIns = $db->prepare("INSERT INTO CONFIG (ID, NAME, VALUE, DESCRIPTION) VALUES(?,?,?,?)");
            foreach my $key (keys %m){
                if(index($key,'$')!=0){#per spec. anons are not prefixed with an '$' as signifier.
                    my $val = $m{$key};
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
        elsif #At times not passing in the hash of expected anons we read in the custom tz map file if it exists.
        (-e $ftzmap){ open(my $fh, "<:perlio", $ftzmap) or die "Can't open '$ftzmap': $!";
            read  $fh, $TIME_ZONE_MAP, -s $fh;
            close $fh;
        }
        &setTimezone;
    }
    catch {
        SettingsException->throw(error=>"DSN:$DSN \@Settings::getConfiguration.ERR ->[$@]", show_trace=>$DEBUG);
    };return
}

sub timeFormatSessionValue {
    my $v = shift;
    my $ret = "+2m";
    if(!$v){$v=$ret}    
    if($v !~ /^\+/){$v='+'.$v.'m'}# Must be positive added time
    # Find first match in whatever passed.
    my @a = $v =~ m/(\+\d+[shm])/gis;    
    if(scalar(@a)>0){$v=$a[0]}
    # Test acceptable setting, which is any number from 2, having any s,m or h. 
    if($v =~ m/(\+*[2-9]\d*[smh])|(\+[1-9]+\d+[smh])/){
        # Next is actually, the dry booger in the nose. Let's pick it out!
        # Someone might try to set in seconds value to be under two minutes.
        @a = $v =~ m/(\d[2-9]\d+)/gs;        
        if(scalar(@a)>0 && int($a[0])<120){return $ret}else{return $v}
    }
    elsif($v =~ m/\+\d+/){# is passed still without time unit? Minutetise!
        $ret=$v
    }
    return $ret;
}

# @new since  v.2.4 (20210903), it is staggaring how many options we have to setup colors and style, CSS, HTML, CNF
# CNF should be only used. So the code and css files doesn't have to change. For now CNF isn't used, but the following:
my %theme = (css=>'wsrc/main.css',colBG=>'#c8fff8',colSHDW=>'#9baec8;');
sub theme{$S_=shift; return $theme{$S_}}
sub setupTheme {
    given ($THEME){
        when ("Sun")   { %theme = (css=>'wsrc/main_sun.css',   colBG=>'#FFD700', colSHDW=>'#FFD700') }
        when ("Moon")  { %theme = (css=>'wsrc/main_moon.css',  colBG=>'#000000', colSHDW=>'#DCDCDC') }
        when ("Earth") { %theme = (css=>'wsrc/main_earth.css', colBG=>'#228B22', colSHDW=>'#8FBC8F') }
        default{
        %theme = (css=>'wsrc/main.css',colBG=>'#c8fff8',colSHDW=>'#9baec8');            # Standard;
        }
    }
}

sub schema_tables{
    my ($db) = @_;
    my %tables = ();
    if(Settings::isProgressDB()){        
        my @tbls = $db->tables(undef, 'public');
        foreach (@tbls){
            my $t = uc substr($_,7); #We check for tables in uc.
            $tables{$t} = 1;
        }
    }
    else{
        my $pst = selectRecords($db,"SELECT name FROM sqlite_master WHERE type='table' or type='view';");        
        while(my @r = $pst->fetchrow_array()){
            $tables{$r[0]} = 1;
        }
    }
    return \%tables;
}

#From v.1.8 Changed
sub renumerate {
    my $db = shift;
    my $CI = 'rowid'; $CI = 'ID' if $IS_PG_DB;
    my %stbls=%{schema_tables($db)};
    #Renumerate Log! Copy into temp. table.
    my $sql = "CREATE TABLE LIFE_LOG_TEMP_TABLE AS SELECT * FROM LOG order by $CI;";
    if($stbls{'LIFE_LOG_TEMP_TABLE'}){
       $db->do('DROP TABLE LIFE_LOG_TEMP_TABLE;');
    }
    $db->do($sql);    
    # Delete any possible orphaned Notes records.
    my $st = selectRecords($db, "SELECT LID, LOG.$CI from NOTES LEFT JOIN LOG ON NOTES.LID = LOG.$CI WHERE LOG.$CI is NULL;");
    while(my @row=$st->fetchrow_array()) {
        $db->do("DELETE FROM NOTES WHERE LID=".$row[0].";")
    }    
    $st->finish();

    if($IS_PG_DB){$db->do('DROP TABLE LOG CASCADE;')}else{$db->do('DROP TABLE LOG;')}
    
    $db->do(&createLOGStmt);
    $db->do('INSERT INTO LOG (ID_CAT, DATE, LOG, RTF ,AMOUNT, AFLAG, STICKY)
                       SELECT ID_CAT, DATE, LOG, RTF, AMOUNT, AFLAG, STICKY FROM life_log_temp_table ORDER by DATE;');

    #Update  notes table with date ordered log id for reference sake.
    $st = selectRecords($db, "SELECT $CI, DATE FROM life_log_temp_table WHERE RTF > 0 ORDER BY DATE;");
    while(my @row=$st->fetchrow_array()) {
        my $ID_OLD   = $row[0];
        my $sql_date = $row[1];  #$sql_date =~ s/T/ /;
        # if(!$IS_PG_DB){           
        #   $sql_date = DateTime::Format::SQLite->parse_datetime($sql_date);
        # }
        $sql = "SELECT $CI DATE FROM LOG WHERE RTF > 0 AND DATE = '".$sql_date."';";
        my @new  = selectRecords($db, $sql)->fetchrow_array();
        if(scalar @new > 0 && $new[0] ne $ID_OLD){
             try{#can fail here, for various reasons.
                $sql="UPDATE NOTES SET LID =". $new[0]." WHERE LID=". $ID_OLD .";";
                $db->do($sql);
             }
             catch{
                 SettingsException->throw(error=>"\@Settings::renumerate Database error encountered. sql->$sql", show_trace=>$DEBUG);
             };
        }    
    }    
    $st->finish();


    $db->do('DROP TABLE LIFE_LOG_TEMP_TABLE;');
}

sub selectRecords {
    my ($db, $sql) = @_;
    if(scalar(@_) < 2){
         die  "Wrong number of arguments, expecting Settings::selectRecords(\$db, \$sql) got Settings::selectRecords('@_').\n";
    }
    try{
        my $pst	= $db->prepare($sql);                
        return 0 if(!$pst);
        $pst->execute();
        return $pst;
    }catch{
                SettingsException->throw(error=>"Database error encountered!\n ERROR->$@\n SQL-> $sql DSN:".$DSN, show_trace=>$DEBUG);
    };
}

sub getTableColumnNames {
        my ($db, $table_name) = @_;
        if(scalar(@_) < 2){
                SettingsException->throw("ERROR Argument number is wrong->db is:$db\n", show_trace=>$DEBUG);
        }
        
        my $pst = selectRecords($db, "SELECT name FROM PRAGMA_table_info('$table_name');");
        my @ret = ();
        while(my @r = $pst->fetchrow_array()){
            push @ret, $r[0];
        }
        
}

sub printDebugHTML {
    my $msg = shift; print qq(<!-- $msg -->) if $msg;
}

sub toLog {
    my ($db,$log,$cat) = @_;
    if(!$db){SettingsException->throw("Database handle not passed!")}
    my $stamp = getCurrentSQLTimeStamp();
        if(!$cat){
            my @arr = selectRecords($db,"SELECT ID FROM CAT WHERE NAME LIKE 'System Log' or NAME LIKE 'System';")->fetchrow_array();
            if(@arr){$cat = $arr[0];}else{$cat = 6;}
        }
       $log =~ s/'/''/g;
       if(length($log)>$DBI_LVAR_SZ){SettingsLimitSizeException->throw("Log size limit ($DBI_LVAR_SZ) exceeded, log length is:".length($log))}
       $db->do("INSERT INTO LOG (ID_CAT, DATE, LOG) VALUES($cat, '$stamp', '$log');");
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
     my $dt;
     if(anon('auto_set_timezone')){$dt = DateTime->from_epoch(epoch => time())}
     else{                         $dt = DateTime->from_epoch(epoch => time(), time_zone=> $TIME_ZONE)}     
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
    my $dbs = selectRecords($db, "SELECT ID, VALUE FROM CONFIG WHERE NAME LIKE '$name';");
    my @row = $dbs->fetchrow_array();
    if(scalar @row > 0){
       return $row[1];
    }
    else{
       return 0;
    }
}
our $cnf_id_range;
our %cnf_ids_taken = ();
sub configPropertyRange {
   $cnf_id_range = shift;
   die "CONFIG_META value->$cnf_id_range" if $cnf_id_range !~ /\d+/;
}
# The config property can't be set to an empty string "", set to 0 to disable is the mechanism.
# So we have an shortcut when checking condition, zero is not set, false or empty. So to kick in then the app settings default.
# Setting to zero, is similar having the property (which is an anon) disabled in the config file. That in the db must be reflected to zero.
# You have to set/update with full parameters.
#
# Get by id   call -> Settings::configProperty($db, $id);
# Get by name call -> Settings::configProperty($db, $name);
# Get by name call -> Settings::configProperty($db, 0, $name);
# Set it up   call -> Settings::configProperty($db, 0, $name, $value);
sub configProperty {
    my($db, $id, $name, $value) = @_;  my $sql;
    if (defined($db)&&defined($id)&&!defined($value)){  #trickeryy here to obtain existing.      
        my $dbs = selectRecords($db, looks_like_number($id) ? "SELECT VALUE FROM CONFIG WHERE ID = $id;":
                                                              "SELECT VALUE FROM CONFIG WHERE NAME like '$id'");
        my @r = $dbs->fetchrow_array();
        return $r[0];
    }
    else{
        $id = '0' if !defined($id);
    }
    if(!defined($db)  || !defined($value)){
        SettingsException->throw(
            error => "ERROR Invalid number of arguments in call -> Settings::configProperty('$db',$id,'$name','$value')\n",  show_trace=>$DEBUG
            );
    };
    if($id && !$name){#ew update by id with value arument, whis is passed as an valid argument.
        $sql = "UPDATE CONFIG SET VALUE='".$value."' WHERE ID=".$id.";";
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
    else{# if id 0 we will find by name.
        my $dbs = selectRecords($db, "SELECT ID, NAME FROM CONFIG WHERE NAME LIKE '$name';");
        if($dbs->fetchrow_array()){
            $db->do("UPDATE CONFIG SET VALUE = '$value' WHERE NAME LIKE '$name';");
        }
        else{# For new config properties we must check, not to overide by accident dynamically system settings in the db.
            if($cnf_id_range && $name ne 'RELEASE_VER'){ # META check! Do not overide config annon placed. i.e. same id used for different properties to create them.
            if($id<$cnf_id_range){SettingsException->throw(
                  error => "ERROR Invalid id value provided, it is not in reserve meta range-> Settings::configProperty('$db',$id,'$name','$value')\n",
                  show_trace=>$DEBUG)}
            if($_=$cnf_ids_taken{$id}){ die "ERROR Config property id: $id is already taken by: $name\n",}            
            }
            $sql = "INSERT INTO CONFIG (ID, NAME, VALUE) VALUES ($id, '$name', '$value');";
            try{                
                $db->do($sql);
                $cnf_ids_taken{$id} = $name;
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

sub connectDBWithAutocommit {
    connectDB(undef,undef,undef,shift);
}
sub connectDB {
    my ($d,$u,$p,$a) = @_;    
    $u = $alias if !$u;
    $p = $alias if !$p;
    $a = 1      if !$a;
    my $db =$u;
    if(!$d){$db = 'data_'.$u.'_log.db';$d=$u}
    else{   $db = 'data_'.$d.'_log.db';$dbname = $d if !$dbname}
    $DBFILE = $LOG_PATH.$db;
        if ($IS_PG_DB)  {
            $DSN = $DBI_SOURCE .'dbname='.$d;
        }else{
            $DSN = $DBI_SOURCE .'dbname='.$DBFILE;        
        }    
    try{        
        return DBI->connect($DSN, $u, $p, {AutoCommit => $a, RaiseError => 1, PrintError => 0, show_trace=>1});
    }catch{           
       LifeLogException->throw(error=>"<p>Error->$@</p><br><pre>DSN: $DSN</pre>",  show_trace=>1);
    }
}

my  @F = ('', '""', 'false', 'off', 'no', 0);# Placed the 0 last, as never will be checked for in toPropertyValue.
my  @T  = (1, 'true', 'on', 'yes');
# my  $reg_autonom = qr/(<<)(.+?)(<)(.*[>]+)*(\n*.+\s*)(>{2,})/mp;
# sub parseAutonom { #Parses autonom tag for its crest value, returns undef if tag not found or wrong for passed line.
#     my $tag  = shift;
#     my $line = shift;
#     return if $line =~ /^\s*[\/#]/; #standard start of single line of comment, skip.    
#     if($line =~ /$reg_autonom/g){
#         #my ($t,$val,$desc) = ($2,$4,$5);
#          my ($t,$val) = ($2,$4);   
#         # if ($ins =~ />$/){
#         #     chop $ins; $val=$ins
#         # }else{$val=$ins}
#         #die "TESTING {\n$t=$ins \n[$val]\n\n}" if $t =~ /^\^\D*/;
#         $val =~ s/""$//g; #empty is like not set
#         $val =~ s/^"|"$//g;        
#         if($t eq $tag&&$val){           
#            return toPropertyValue( $val );
#         }        
#     }
#     return;
# }
#my $reg_autonom = qr/(<<)(.+?)(<)(\n*.+\s*)(>{3,})/mp;
my $reg_autonom = qr/(<<)(.+?)(<(.*)>*|<)(\n*.+\s*)(>{2,3})/mp;
sub parseAutonom { #Parses autonom tag for its crest value, returns undef if tag not found or wrong for passed line.
    my $tag  = shift;
    my $line = shift;
    return if $line =~ /^\s*[\/#]/; #standard start of single line of comment, skip.
    if($line =~ /$reg_autonom/g){
        my ($t,$val) = ($2,$4);       
        $val =~ s/""$//g; #empty is like not set
        $val =~ s/^"|"$//g;chop $val if $val =~ s/>$//g;
        if($t eq $tag&&$val){           
           return toPropertyValue( $val );
        }        
    }

    return;
}

sub toPropertyValue {
    my $prm = shift;
    if($prm){
       my $p = lc $prm; 
       foreach(@T){return 1 if $_ eq $p;}
       foreach(@F){return 0 if $_ eq $p;}       
    }
    return $prm;
}

use Crypt::Blowfish;
use Crypt::CBC;
sub newCipher {
    my $p = shift;    
       $p = $alias.$p.Settings->CIPHER_KEY;
       $p =~ s/(.)/sprintf '%04x', ord $1/seg;
       $p = substr $p.CIPHER_PADDING, 0, 58;
       Crypt::CBC->new(-key  => $p, -cipher => 'Blowfish');
}

sub saveCurrentTheme {
    my $theme = shift;
    if($theme){
        open (my $fh, '>', $LOG_PATH.'current_theme') or die $!;
        print $fh $theme;
        close($fh);
    }return;
}
sub loadLastUsedTheme {    
    open my $fh, '<', $LOG_PATH.'current_theme' or return $THEME;
    $THEME = <$fh>;
    close($fh);    
    &setupTheme; return
}
sub saveReserveAnons {
    my $meta = $anons{META}; #since v.2.3
    my @dr = split(':', dbSrc());
    LifeLogException->throw(error=>"Meta anon property ^CONFIG_META not found!\n".
                                   "You possibly have an old main.cnf file there.",  show_trace=>1) if not $meta;
    try{        
        my $db = connectDBWithAutocommit(0);
        open (my $fh, '>', $LOG_PATH.'config_meta_'.(lc($dr[1])).'_'.$dbname) or die $!;
         print $fh $meta;
         #It is reserve meta anon type, value (200) is not mutuable, internal.
         my $dbs = selectRecords($db, "SELECT ID, NAME, VALUE FROM CONFIG WHERE ID >= 200;"); 
        while(my @r=$dbs->fetchrow_array()){
            print $fh "$r[0]|$r[1] = $r[2]\n" if $r[0] =~ /^\^/;
        }
        close($fh);return

    }catch{           
       LifeLogException->throw(error=>"<p>Error->$@</p><br><pre>DSN: $DSN</pre>",  show_trace=>$DEBUG);
    }return
}
sub loadReserveAnons(){    
    try{        
        my @dr = split(':', dbSrc());    
        my $db = connectDBWithAutocommit(0);
        my %reservs = ();        
        my $stInsert = $db->prepare('INSERT INTO CONFIG VALUES(??);');
        my $stUpdate = $db->prepare('UPDATE CONFIG (NAME, VALUE) WHERE ID =? VALUES(?, ?);');
        my $dbs = selectRecords($db, "SELECT ID, NAME, VALUE FROM CONFIG WHERE ID >= 200;"); 
        $db->do('BEGIN TRANSACTION;');
                    while(my @r=$dbs->fetchrow_array()){
                    $reservs{$r[1]} = $r[2] if !$reservs{$r[1]}
                    }
                    open (my $fh, '<', $LOG_PATH.'config_meta_'.(lc($dr[1])).'_'.$dbname);
                    while (my $line = <$fh>) {
                        chomp $line;
                        my @p = $line =~ m[(\S+)\s*=\s*(\S+)]g;
                        if(@p>1){
                            my $existing_val = $reservs{$p[1]};
                            if(!$existing_val){
                                $stInsert->execute($p[1], $p[2]);
                            }
                            elsif($existing_val ne $p[2]){
                                $stUpdate->execute($p[0], $p[1], $p[2]);
                            }
                        }
                    }
                    close($fh);
        $db->commit();       
    }catch{       
       LifeLogException->throw(error=>"<p>Error->$@</p><br><pre>DSN: $DSN</pre>",  show_trace=>1);
    }
    return 1;    
}

sub dumpVars {
    # Following will not help, as in perl package variables are codes 
    # and the web container needs sudo permissions for memory access.
    # my $class = shift;    
    # my $self = bless {}, $class;
    # use DBG;
    # dmp $self;
    #
    # We need to do it manually:
    return qq/
release        {$RELEASE_VER}
logPath        {$LOG_PATH} 
logPathSet     {$LOG_PATH}
timezone       {$TIME_ZONE}
transparent    {$TRANSPARENCY}
transimage     {$TRANSIMAGE}
language       {$LANGUAGE}
sessionExprs   {$SESSN_EXPR}
imgWidthHeight {$IMG_W_H}
pagePrcWidth   {$PRC_WIDTH}
frameSize      {$FRAME_SIZE}
universalDate  {$DATE_UNI}
recordLimit    {$REC_LIMIT}
autoWordLimit  {$AUTO_WRD_LMT}
autoWordLength {$AUTO_WRD_LEN}
autoLogoff     {$AUTO_LOGOFF}
viewAllLimit   {$VIEW_ALL_LMT}
displayAll     {$DISP_ALL}
trackLogins    {$TRACK_LOGINS}
windowRTFSize  {$RTF_SIZE}
keepExcludes   {$KEEP_EXCS}
bgcol          {$BGCOL}
css            {$TH_CSS}
js             {$JS}
compressPage   {$COMPRESS_ENC}
debug          {$DEBUG}
dbSrc          {$DBI_SOURCE}  
dbVLSZ         {$DBI_LVAR_SZ}
dbFile         {$DBFILE}
dbName         {$dbname}
dsn            {$DSN}
isProgressDB   {$IS_PG_DB} 
sqlPubors      {$SQL_PUB}        
        /;
}

1;