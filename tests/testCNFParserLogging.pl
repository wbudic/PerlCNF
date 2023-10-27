#!/usr/bin/env perl
use warnings; use strict;
use Syntax::Keyword::Try;
#no critic "eval"
use lib "/home/will/dev/PerlCNF/system/modules";
use lib "tests";

require CNFParser;
require TestManager;
my $test = TestManager -> new($0);
my $cnf;

try{
    ###
    # Test instance creation.
    #
    my $logfile = 'zzz_temp.log';
    die $test->failed() if not $cnf = CNFParser->new(undef,{DO_ENABLED=>1,DEBUG=>1,'%LOG'=>{enabled=>1,file=>$logfile, tail=>10}});
    $test->case("Passed new instance CNFParser with log setings.");

    $cnf->log("$_") for (1..20);
    $cnf->parse(undef,'<<<test this>>>');
    $test->evaluate('test == this', $cnf->anon('test'),'this');
    #
    $test-> nextCase();

    $test->case("Has log only tail last 10 lines?");
    open (my $fh, "<", $logfile) or die $!;
    my $cnt=11;
    while(my $line = <$fh>){
        chomp($line);
        $test -> evaluate("Log $line ends with $cnt?", $cnt, $line =~ m/(\d*)$/);
        $cnt++;
    }
    close $fh;
    $test -> evaluate("Is ten lines tailed?", ($cnt-11), 10);
    `rm $logfile`;
    #
    $test->done();
    #
}
catch{
   $test -> dumpTermination($@);
   $test -> doneFailed();
}

#
#  TESTING ANY POSSIBLE SUBS ARE FOLLOWING FROM HERE  #
#