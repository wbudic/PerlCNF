#!/usr/bin/env perl
##
# Part of Test Manager running all your test files and collecting stats.
# Nothing quite other than it, yet does exists.
##
use v5.30;
#use warnings; use strict; 
use Syntax::Keyword::Try;
use Date::Manip;
use Term::ANSIColor qw(:constants);
use IPC::Run qw( run timeout );

use lib "./local";
use lib "./tests";

try{
    require TestManager;
}catch{
    print RED "Failed to require -> ".WHITE."TestManager.pm".RED.
    "\nPlease run tests from the project directory.\n";
    exit 1
}

my $TEST_LOCAL_DIR = './tests';
my @failed;
my $SUPRESS_ISSUES = ($ARGV[-1] eq "--display_issues")?0:1;

###
#  Notice - All test are to be run from the project directory.
#  Not in the test directory of this file.
#  i.e.: perl ./tests/testAll.pl
#  If using the PerlLanguageServer, i.e. for debugging, make sure it has started an instance, 
#  or doesn't have one hanging or already running in some process on the same port.
###
print '-'x100, "\n";
my $manager = TestManager->new("Test Suit [ $0 ] (".(scalar localtime).")");
print '-'x100, "\n";
try{
    opendir my($dh), $TEST_LOCAL_DIR or die WHITE."Couldn't open dir '$TEST_LOCAL_DIR':".RED." $!";
    #grep all prefixed test*.pl excluding this file, as it is running.
    my @files = grep { !/^\./ && /^test.*?\.pl$/ && $0 !~ m/$_$/ && -f "./tests/$_" } readdir($dh);
    closedir $dh;

    my ($test_pass, $test_fail, $test_cases, @OUT, %WARN);
    
    foreach my $file(sort @files) {        
        
        $file = "./tests/$file";            
        my ($in,$output, $warnings);
        my @perl = ('/usr/bin/env','perl',$file);
        print "Running->$file\n";
        ###
        run  (\@perl, \$in, \$output, '2>>', \$warnings);
        ###
        my @test_ret = $output=~m/(\d*)\|(.*)\|($file)$/g;
        $output=~s/\d*\|.*\|$file\s$//g;
        push @OUT, $output;
            if ($warnings){
                for(split "\n", $warnings){
                    $WARN{$file} = $warnings;
                }
            }
        if(@test_ret && $test_ret[1] eq 'SUCCESS'){
            $test_pass++;
            #This is actually global test cases pass before sequently hitting an fail.
            $test_cases+= $test_ret[0];
        }else{
            $test_fail++;
            my $failed = BOLD. RED. "Failed Test File -> ". WHITE. $file."\n". RESET;
            print $failed; 
            print RED, "\t", $warnings, RESET;
            $failed[@failed] = $failed;
        }
        
    }
    foreach(@OUT){        
            print $_;        
    }
    print '-'x100, "\n";
    if($test_fail){
        print BOLD BRIGHT_RED, "HALT! Not all test have passed!\n",BLUE,
        "\tNumber of test cases run: $test_cases\n",        
        "\tPassed test count: ", BRIGHT_GREEN, "$test_pass\n", BLUE
        "\tFailed test file count: ", BOLD RED,"$test_fail\n",BLUE,        
        join  "",@failed,
        BOLD WHITE, "Finished with test Suit ->$0\n", RESET;

    }elsif($test_pass){
        print BOLD.BLUE."Test Suit:", RESET WHITE, " $0 [\n";
        foreach (@files) {
                print WHITE, "\t\t\t$_\n",;
        }
        print "\t\t]\n",RESET;

        print BOLD BLUE "Test files ($test_pass of them), are having $test_cases cases. Have all ", BRIGHT_GREEN ,"SUCCESSFULLY PASSED!", RESET, WHITE,
                    " (".(scalar localtime).")\n", RESET;
    }else{
        print BOLD BRIGHT_RED, "No tests have been run or found!", RESET WHITE, " $0\n", RESET;
    }

    if(not $SUPRESS_ISSUES && %WARN){
        print BOLD YELLOW, "Buddy, sorry to tell you. But you got the following Perl Issues:\n",BLUE;
        foreach(keys %WARN){ 
            my $w = $WARN{$_};
            $w=~ s/\s+eval\s\{...\}.*$//gs;
            $w=~ s/\scalled\sat/\ncalled at/s;
            print "In file:  $_".MAGENTA."\n",$w."\n", BLUE;
        }
        print RESET;        
    }else{
        print "To display all encountered issues or warnings, on next run try:\n\tperl tests/testAll.pl --display_issues\n"
    }
    print '-'x100, "\n";
}
catch{ 
   $manager -> dumpTermination($@)
}

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