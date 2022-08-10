#!/usr/bin/env perl
use v5.12;
use warnings; use strict; 
use Syntax::Keyword::Try;
use Term::ANSIColor qw(:constants);
use IPC::Run qw( run timeout );

use lib "./local";
use lib "./tests";

try{
    require TestManager;
}catch{
    print RED "Failed to require -> ".WHITE."./local/TestManager.pm".RED.
    "\nDid you start this test suit from the project directory please?\n";
    exit 1
}

my $TEST_LOCAL_DIR = './tests';

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
    my @files = grep { !/^\./ && /\.pl$/ && -f "./tests/$_" } readdir($dh);
    closedir $dh;

    my ($test_pass, $test_fail, $test_cases, @OUT, %WARN);
    
    foreach my $file(@files) {        
        if($0 !~ m/$file$/){ 
            $file = "./tests/$file";            
            my ($in,$output, $warnings);
            my @perl = ('/usr/bin/env','perl',$file);    
            ###
            run  (\@perl, \$in, \$output, '2>>', \$warnings);
            ###
            my @test_ret = $output=~m/(\d*)\|(.*)\|($file)$/g;
            $output=~s/\d*\|.*\|$file\s$//g;
            push @OUT, $output;
             if ($warnings){
                for(split "\n", $warnings){
                    $WARN{$_} = $file;
                }
            }
            if(@test_ret && $test_ret[1] eq 'SUCCESS'){
                $test_pass++;
                #This is actually global test cases pass before sequently hitting an fail.
                $test_cases+= $test_ret[0];
            }else{
                $test_fail++;
                print BOLD RED "Failed Test File -> ", WHITE, "$file\n", RESET
            }
        }
    }
    foreach(@OUT){        
            print $_;        
    }
    print '-'x100, "\n";
    if($test_fail){
        print BOLD BRIGHT_RED, "HALT! Not all test have passed!\n",BLUE,
        "\tFailed test file count: ", BOLD RED,"$test_fail\n",BLUE,
        "\tPassed test count: $test_pass\n",
        "\tNumber of test cases run: $test_cases\n",
        WHITE, "Finished with test Suit ->$0\n", RESET;

    }elsif($test_pass){
        print BOLD BLUE "Test files ($test_pass of them), having $test_cases cases. Have all ", BRIGHT_GREEN ,"SUCCESSFULLY PASSED!", RESET, WHITE,
                    " (".(scalar localtime).")".BOLD.BLUE."\nFor Test Suit:", RESET WHITE, " $0\n", RESET
                   
    }else{
        print BOLD BRIGHT_RED, "No tests have been run or found!", RESET WHITE, " $0\n", RESET;
    }
    if(%WARN){
        print BOLD YELLOW, "Buddy, sorry to tell you. But you got the following Perl Issues:\n",BLUE;
        foreach(keys %WARN){        
            print "In file:  $WARN{$_}".MAGENTA."\n",$_."\n", BLUE;        
        }
        print RESET;
    }
    print '-'x100, "\n";
}
catch{ 
   $manager -> dumpTermination($@)
}
