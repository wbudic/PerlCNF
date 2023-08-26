#!/usr/bin/env perl
##
# Module installer for projects.
# Run this script from any Project directory containing perl modules or scripts.
##
use warnings; use strict;
###
# Prerequisites for this script itself. Run first:
# cpan Term::ReadKey;
# cpan Term::ANSIColor;
## no critic (ProhibitStringyEval)  
use Term::ReadKey;
use Term::ANSIColor qw(:constants);

use constant PERL_FILES_GLOB => "*local/*.pl local/*.pm system/modules/*.pm tests/*.pm tests/*.pl .pl *.pm *.cgi";

my $project = `pwd`."/".$0; $project =~ s/\/.*.pl$//g;  $project =~ s/\s$//g;
my @user_glob;
our $PERL_VERSION = $^V->{'original'}; my $ERR = 0; my $key;

print WHITE "\n *** Project Perl Module Installer coded by ",BRIGHT_RED, "https://github.com/wbudic", WHITE,"***", qq(
         \nRunning scan on project path:$project 
         \nYou have Perl on $^O [$^X] version: $PERL_VERSION\n
);
print BLUE "<<@<\@INC<\n# Your default module package paths:\n", YELLOW; 
local $. = 0; foreach(@INC){  
  print $.++.".: $_\n"; 
}
print BLUE ">>\n", RESET;
if($> > 0){
  print "You are NOT installing system wide, which is required for webservers CGI.\nAre you sure about this?\n"
}else{
  print "You are INSTALLING modules SYSTEM WIDE, are you sure about this?\n"
}
if(@ARGV==0){
  print qq(\nThis program will try to figure out now all the modules 
  required for this project, and install them if missing.
  This can take some time.
  ); 
  print RED "Do you want to proceed (press either the 'Y'es or 'N'o key)?", RESET;

do{
  ReadMode('cbreak');  
  $key = ReadKey(0); print "\n";
  ReadMode('normal');
    exit 1 if(uc $key eq 'N');
    $key = "[ENTER]" if $key =~ /\n/;
    print "You have pressed the '$key' key, that is nice, but why?\nOnly the CTRL+C/Y/N keys do something normal." if uc $key ne 'Y';
  }while(uc $key ne 'Y');
}
else{
  foreach(@ARGV){
    if(-d $_){
      $_ =~ s/\s$//g;
      print "\nGlobing for perl files in $project/$_";
      my @located = glob("$_/*.pl $_/*.pm");
      print " ... found ".@located." files.";
      push @user_glob, @located;
      
    }else{
      warn "Argument: $_ is not a local directory."
    }
  }
}

my @locals=(); 
print "\nGlobing for perl modules in project $project";
my @perl_files = glob(PERL_FILES_GLOB); 
print " ... found ".@perl_files." files.\n";
push @perl_files, @user_glob;
my %modules; my %localPackages;
foreach my $file(@perl_files){
   next if $0 =~ /$file$/;
   if($file =~ /(\w*)\.pm$/){
      $localPackages{$1}=$file;
   }
   print "\nExamining:$file\n";      
   my $res  =  `perl -ne '/\\s*(^use\\s([a-zA-Z:]*))\\W/ and print "\$2;"' $file`;
   my @list = split(/;+/,$res);
   foreach(@list){
     if($_=~ /^\w\d\.\d+.*/){
      print "\tA specified 'use $_' found in ->$file\n";
      if($PERL_VERSION ne $_){         
         $_ =~s/^v//g;
         my @fv = split(/\./, $_);
         $PERL_VERSION =~s/^v//g;
         my @pv = split(/\./, $PERL_VERSION);
         push @fv, 0 if @fv < 3;
         for my$i(0..$#fv){
           if( $pv[$i] < $fv[$i] ){
              $ERR++; print "\n\t\033[31mERROR -> Perl required version has been found not matching.\033[0m\n";
              last
           }
         }
      }
     }
   }
   foreach(@list){    
    $_ =~ s/^\s*|\s*use\s*//g;
    $_ =~ s/[\'\"].*[\'\"]$//g;    
    next if !$_ or $_ =~ /^[a-z]|\d*\.\d*$|^\W/;
    $_ =~ s/\(\)|\(.*\)|qw\(.*\)//g;
    $modules{$_}=$file if $_;
    print "$_\n";
   }
   if($file=~/\.pm$/){# it is presumed local package module.  
      $locals[@locals] = `perl -ne '/\\s*(^package\\s(\\w+))/ and print "\$2" and exit' $file`;
   }
}

print WHITE "\nList of Modules required for thie project:\n";
my @missing=(); 
foreach my $mod (sort keys %modules){
    my $missing;
    eval "use $mod";
    if ($@){
      $missing[@missing] = $mod;
      print MAGENTA "\t$mod \t in ", $modules{$mod}," is suspicious?\n";
    }else{
      print BLUE "\t$mod\n" 
    }
}foreach(@missing){
  if(exists $localPackages{$_}){
      delete $modules{$_}
  }else{
      print BRIGHT_RED $_, MAGENTA, " is missing!\n"
  }
}
my %skip_candidates;
my $missing_count = @missing;
if($missing_count>0){
  foreach my $candidate(@missing){
    foreach(@locals){
      if($_ eq $candidate && not exists $skip_candidates{$_}){
        $missing_count--;        
        $skip_candidates{$_} = 1;
        print GREEN, "Found the missing $candidate module in locals.\n"
      }
    }
  }
}
my $perls = `whereis perl`;
print GREEN, "Following is all of ",$perls;
print YELLOW, "Reminder -> Make sure you switched to the right brew release.\n" if $perls =~ /perlbrew/; 
print RESET, "Number of local modules:",scalar(@locals),"\n";
print RESET, "Number of external modules:",scalar(keys %modules),"\n";
print RESET, "Number of cpan modules about to be tried to install:",$missing_count,"\n";

print GREEN, qq(
Do you still want to continue to compile/test/install or check further modules?
Only the first run is the depest and can take a long time, i.e. if you have to install over 5 modules.
At other times this will only check further your current status.

Now (press either the 'Y'es or 'N'o key) please?), RESET;
do{
ReadMode('cbreak');  
$key = ReadKey(0); print "\n";
ReadMode('normal');
  exit 1 if(uc $key eq 'N');
  $key = "[ENTER]" if $key =~ /\n/;
  print "You have pressed the '$key' key, that is nice, but why?\nOnly the CTRL+C/Y/N keys do something normal.\n" if uc $key ne 'Y';
}while(uc $key ne 'Y');

my ($mcnt,$mins) = (0,0);
my @kangaroos = sort keys %skip_candidates;

##
# Some modules if found to be forcefeed. can be hardcoded here my friends, why not?
# You got plenty of space on you disc, these days.
##
$modules{'Syntax::Keyword::Try'}=1;
$modules{'DBD::SQLite'}=1;
$modules{'DBD::Pg'}=1;

MODULES_LOOP: 
foreach my $mod (sort keys %modules){

  foreach(@kangaroos){
      if($_ eq $mod){
        next MODULES_LOOP
      }
  }
  $mcnt++;
  ## no critic (ProhibitStringyEval)
  eval "use $mod";
  if ($@) {
      system(qq(perl -MCPAN -e 'install $mod'));     
      if ($? == -1) {
        print "failed to install: $mod\n";
      }else{  
        my $v = eval "\$$mod\::VERSION";
           $v = $v ? "(v$v)" : "";
        print "Installed module $mod $v!\n";
        $mins++
      }    
  }else{       
   $mod =~ s/\s*$//;   
   my $v = eval "\$$mod\::VERSION";
      $v = $v ? "(v$v)" : "";
      print "Skipping module $mod $v, already installed!\n";
  }
}
print "\nProject $project\nRequires $mcnt modules.\nInstalled New: $mins\n";
print "WARNING! - This project requires in ($ERR) parts code that might not be compatible yet with your installed/running version of perl (v$PERL_VERSION).\n" 
if $ERR;


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