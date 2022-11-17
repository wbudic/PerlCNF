#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;

use lib "./tests";
use lib "./system/modules";

require TestManager;
require CNFParser;

my $test = TestManager -> new($0);
my $cnf;

try{

   ###
   # Test instance with cnf file creation.
   ###
   die $test->failed() if not $cnf = CNFParser->new('./tests/example.cnf');
       $test->case("Passed new instance CNFParser.");
       $test->subcase('CNFParser->VERSION is '.CNFParser->VERSION);   
       $test->subcase('$cnf->{\'$IMMUTABLE\'} is '.$cnf->{'$IMMUTABLE'});   
       $test->evaluate('$IMMUTABLE == "Hello World! "',$cnf->{'$IMMUTABLE'},'Hello World! ');
    #
    $test->nextCase();  
    #

    ###
    # Test constances.
    ###
    $test->case("Test mutability.");
    try{
       $cnf->{'$IMMUTABLE'} = "change?";
       $test->failed('Variable should be a constance!');
    }catch{
       $test->subcase('Passed test is constance.');
    }
    try{
       $$cnf->{'$DYNAMIC_IMMUTABLE'} = "new";;
       $test->failed('Variable should not be alloed added constance!');
    }catch{
       $test->subcase('Passed dynamic added constance not possible.');
    }

    die $test->failed() if not $cnf = CNFParser->new('./tests/example.cnf',{
                                                        '$DYNAMIC_IMMUTABLE'=>'app assigned constant value'
                                                    });
    $test->evaluate('$DYNAMIC_IMMUTABLE == "app assigned constant value"',$cnf->{'$DYNAMIC_IMMUTABLE'},
                        'app assigned constant value');
    #
    $test->nextCase();  
    #
    
    ###
    # Test anon's.
    ###
    $test->case("Test mutability.");
    my $me_too = $cnf->anon('ME_TOO');
    $test->evaluate("$me_too == 1024",$me_too, 1024);

    die "Should be same" unless $me_too eq $cnf->anon('ME_TOO'); 
    ${$cnf->anon()}{'ME_TOO'} = $me_too * 8;
    
    $test->evaluate("Changed in config ME_TOO == 1024 * 8", $cnf->anon('ME_TOO'), 1024 * 8);
    die "Should not be same" unless $me_too ne $cnf->anon('ME_TOO'); 


    #   
    $test->done();    
    #
}
catch{ 
   $test -> dumpTermination($@);   
   $test -> doneFailed();
}

