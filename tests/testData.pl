#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;

use lib "tests";
use lib "system/modules";



require TestManager;
require CNFParser;

my $test = TestManager -> new($0);
my $cnf;

try{

   ###
   # Test instance creation.
   ###
   die $test->failed() if not $cnf = CNFParser->new();
       $test->case("Passed new instance CNFParser.");
       $test->subcase('CNFParser->VERSION is '.CNFParser->VERSION);   

    

   #
   my $LifeLogConfigAnon = q(!CNF2.2
   <<CONFIG<4>
00|$RELEASE_VER = 2.4`LifeLog Application Version.
01|$REC_LIMIT   = 25`Records shown per page.
03|$TIME_ZONE   = Australia/Sydney`Time zone of your country and city.
05|$PRC_WIDTH   = 80`Default presentation width for pages.
08|$LOG_PATH    = ../../dbLifeLog/`Path to folder containing data.
10|$SESSN_EXPR  = +30m`Login session expiration time setting, can be seconds, minutes or hours.
12|$DATE_UNI    = 0`Setting of how dates are displayed, universal yyyy-mm-dd or local dd-mm-yyyy.
14|$LANGUAGE	 = English`Default language locale.
18|$IMG_W_H     = 210x120`Default embedded image width.
20|$AUTO_WRD_LMT= 1024`Autocomplete word gathering limit.
22|$AUTO_LOGIN  = 0`Autologin option, that expires only if login out. Enter Credentials in main.cnf.
23|$AUTO_LOGOFF = 0`Auto logoff on session expires, default is false.
24|$FRAME_SIZE  = 0`Youtube frame size settings, 0 - Large, 1 - Medium, 2- Small.
26|$RTF_SIZE    = 2`RTF Document height, 0 - Large, 1 - Medium, 2- Small.
28|$THEME       = Standard`Theme to apply, Standard, Sun, Moon, Earth.
30|$DEBUG       = 0`Development page additional debug output, off (default) or on.
32|$KEEP_EXCS   = 0`Cache excludes between sessions, off (default) or on.
34|$VIEW_ALL_LMT=1000`Limit of all records displayed for large logs. Set to 0, for unlimited.
36|$TRACK_LOGINS=1`Create system logs on login/logout of Life Log.
38|$COMPRESS_ENC=0`Compress Encode pages, default -> 0=false, 1=true.
40|$SUBPAGEDIR  =docs`Directory to scan for subpages like documents.
42|$DISP_ALL    = 1`Display whole log entry, default -> 1=true, 0=false for display single line only.
44|$TRANSPARENCY= 1`Should log panel be transparent, default is yes or on.
50|$CURR_SYMBOL = $`Currency symbol.
>>);
   

    ###
    # Test hsh instance creation.
    ###    
    $test->case("Test LifeLogConfigAnon");
    $cnf->parse(undef,$LifeLogConfigAnon);

    my $CONFIG =  $cnf->anon("CONFIG") ;    
    $test->isDefined('$CONFIG',$cnf);

    #
    $test->subcase("Check old parsing of value algorith.");   

    testOldDataSciptFormat($cnf);

    #
    #   
    $test->done();    
    #
}
catch{ 
   $test -> dumpTermination($@);   
   $test -> doneFailed();
}


sub testOldDataSciptFormat {
    my $cnf = shift;
    
    my $data;    
    my $err;
    my %vars;
    my @lines  = split('\n', $cnf->anon('CONFIG'));
         
    foreach my $line ( @lines ) {
        my @tick = split( "`", $line );
        if ( scalar(@tick) == 2 ) {

       #Specification Format is: ^{id}|{property}={value}`{description}\n
       #There is no quoting necessary unless capturing spaces or tabs for value!
                my %hsh = $tick[0] =~ m[(\S+)\s*=\s*(\S+)]g;
                if ( scalar(%hsh) == 1 ) {
                    for my $key ( keys %hsh ) {
                        my %nash = $key =~ m[(\d+)\s*\|\$\s*(\S+)]g
                          ;    # {id}|{property} <- is the key.
                        if ( scalar(%nash) == 1 ) {
                            for my $id ( keys %nash ) {
                                my $name  = $nash{$id};
                                my $value = $hsh{$key};    # <- {value}.
                                if ( $vars{$id} ) {
                                    $err .=
                                      "UID{$id} taken by $vars{$id}-> $line\n";
                                }
                                else {
                                    
                                }
                            }
                        }
                        else {
                            $err .=
"Invalid, spected {uid}|{setting}`{description}-> $line\nlines:\n@lines";
                        }

                    }    #rof
                }
                else {
                    $err .= "Invalid, spected entry -> $line\n";
                }

            }
            elsif ( length($line) > 0 ) {
                if ( scalar(@tick) == 1 ) {
                    $err .= "Corrupt entry, no description supplied -> $line\n &lt&ltCONFIG&lt;\n".$cnf->anon('CONFIG')."\n&gt&gt;&gt;;\n";
                }
                else {
                    $err .= "Corrupt Entry -> $line\n";
                }
            }
        }
        die $err  if $err;

     
}



