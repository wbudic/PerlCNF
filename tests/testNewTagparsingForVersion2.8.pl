#!/usr/bin/env perl
use warnings; use strict; 
use lib "tests";
use lib "system/modules";

require TestManager;
require CNFParser;

my $test = TestManager->new($0);

use Syntax::Keyword::Try; try {

    ###
    # Test instance creation.
    ###
    die $test->failed()  if not my $cnf = CNFParser->new();
    $test->case("Passed new instance for CNFParser.");
    #

    #  
    $test-> nextCase();
    #

    ###
    # Test parsing HTML tags in instruction.
    ###
    $test->case("Test parsing HTML tags in instruction.");
    my $script = "<<tag1<<HTML></HTML>>>>";
    $test->subcase($script);
    $cnf->parse(undef,$script);
    die $test->failed()  if not $cnf->anon('tag1')  eq '<HTML></HTML>';
    $test->subcase($cnf->anon('tag1') . " from $script passed.");
    #
    $script = "<<tag1< <HTML></HTML> >>>";
    $test->subcase($script);
    $cnf->parse(undef,$script);
    die $test->failed()  if not $cnf->anon('tag1')  eq ' <HTML></HTML> ';
    $test->subcase($cnf->anon('tag1') . " from $script");
    #
    $script = "This is a valid anon-><<A<B>>>";
    $test->subcase($script);    
    $cnf->parse(undef,$script);
    $test->isDefined("A",$cnf->anon('A'));
    $test->evaluate("A==B",$cnf->anon('A'),'B');
    #
    $script = "This is a valid anon with instruction-><<A<B<C>>>";
    $test->subcase($script);
    $cnf->parse(undef,$script);
    $test->isDefined("A",$cnf->anon('A'));
    $test->evaluate("A==C",$cnf->anon('A'),'C');
    #
    $script = '  <<@<@Array<1,2,3,4,5>>>';
    $test->subcase($script);
    $cnf->parse(undef,$script);
    my @a = $cnf->collection('@Array');
    $test->isDefined('@A', @a);
    $test->evaluate("A@ is 5",scalar @a,5);


    $script = q/  <<one<1>>
    <<<two 2>>>
    <<Three>3>>
    <<FILE<text.txt>>>/;
    $test->subcase($script);
    $cnf->parse(undef,$script);
    $test->evaluate("one==1",$cnf->anon('one'),'1');
    $test->evaluate("two==2",$cnf->anon('two'),'2');
    $test->evaluate("Three==3",$cnf->anon('Three'),'3');
    $test->evaluate("FILE==3",$cnf->anon('FILE'),'text.txt');

    #
    $test-> nextCase();
    #

    $test->case("Mauling Example.");
    $script = q/

       <<APP_HELP_TXT<CONST
       This is your applications help text in format of an constance. 
       All you see here can't be dynamically changed.
       You might be able to change it in the script though. 
       And re-run your app.
       >>  

     /;
    $cnf->parse(undef,$script);
    $test->isDefined('APP_HELP_TXT', $cnf->{APP_HELP_TXT});

    #
    $test-> nextCase();
    #
    $test->case("VARIABLE instruction.");

    $script = q/

   <<<VARIABLE

   $var1    =  "No test shall fail!"
   $var2    =  Indeed.   
   other_var= 'capture'
   >>>

      /;
   $cnf->parse(undef,$script);
   $test->isDefined('$var1', $cnf->anon('$var1'));
   $test ->evaluate('$var1', $cnf->anon('$var1'),'No test shall fail!');
   $test->isDefined('$var2', $cnf->anon('$var2'));
   $test->isDefined('other_var', $cnf->anon('other_var'));
    
    #
    $test->done();
    #
}
catch{ 
   $test -> dumpTermination($@);   
   $test->doneFailed();
}


