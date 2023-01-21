#!/usr/bin/env perl
# Module installer for projects.
# This source file is copied and usually placed in a local directory, outside of its project.
# So not the actual or current version, might vary or be modiefied for what ever purpose in other projects.
# Programed by  : Will Budic
# Source Origin : https://github.com/wbudic/PerlCNF.git
# Open Source License -> https://choosealicense.com/licenses/isc/
#
use warnings; 
use strict;
use Term::ReadKey;
use constant PERL_FILES_GLOB => "*.pl *.pm local/*.pl local/*.pm tests/*.pm system/modules/*.pm";

my $project = `pwd`."/".$0; $project =~ s/\/.*.pl$//g;  $project =~ s/\s$//g;
my @user_glob;
our $PERL_VERSION = $^V->{'original'}; my $ERR = 0;

print "\n*** Project Perl Module Intaller ***\n\nYou have Perl on $^O [$^X] version: $PERL_VERSION\n";
print "<<@<\@INC<\n# Your default module package paths:\n"; 
local $. = 0; foreach(@INC){  
  print $.++.".: $_\n"; 
}
print ">>\n";
if($> > 0){
  print "You are NOT installing system wide, this is ok and recommended.\n"
}else{
  print "You are not INSTALLING modules SYSTEM WIDE, are you sure about this?\n"
}
if(@ARGV==0){
  print qq(\nThis program will try to figure out all the modules 
  required for this project, and install them if missing.\nThis can take some time.\nDo you want to procede (press either the 'Y'es or 'N'o key)?);

  my $key; do{
  ReadMode('cbreak');  
  $key = ReadKey(0); print "\n";
  ReadMode('normal');
    exit 1 if(uc $key eq 'N');
    $key = "[ENTER]" if $key =~ /\n/;
    print "You have pressed the '$key' key, that is nice, but why?\nOnly the CTRL+C/Y/N keys do something normal." if $key ne 'Y';
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


print "\nGlobing for perl modules in project $project";
my @perl_files = glob(PERL_FILES_GLOB); 
print " ... found ".@perl_files." files.\n";
push @perl_files, @user_glob;
my %modules; 
foreach my $file(@perl_files){
   next if $0 =~ /$file$/;
   print "\nExamining:$file\n";
   my $res  =  `perl -ne '/\\s*(use\\s(.*))/ and print "\$2;"' $file`;
   my @list = split(/;+/,$res);
   foreach(@list){
     if($_=~ /^\w\d\.\d+.*/){
      print "\tA specified 'use $_' found in ->$file";
      if($PERL_VERSION ne $_){         
         $_ =~s/^v//g;
         my @fv = split(/\./, $_);
         $PERL_VERSION =~s/^v//g;
         my @pv = split(/\./, $PERL_VERSION);
         push @fv, 0 if @fv < 3;
         for my$i(0..3){
           if( $pv[$i] < $fv[$i] ){
              $ERR++; print "\n\tERROR -> Perl required version has been found not matching.\n";
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
}

my ($mcnt,$mins) = (0,0);
foreach my $mod (sort keys %modules){   
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
print "WARNING! - This project requires in ($ERR) parts code that might not be compatible yet with your installed/running version of perl (v$PERL_VERSION).\n" if $ERR;
