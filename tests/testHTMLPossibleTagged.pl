#!/usr/bin/env perl
use warnings; use strict; 
use lib "./tests";
use lib "./system/modules";

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
    # Test parsing HTML tags in value.
    ###
    $cnf->parse(undef,"<<tag1<CONST><HTML></HTML>>>");
    die $test->failed()  if not $cnf->{tag1}  eq '<HTML></HTML>';
    $test->case($cnf->{tag1});
    #

    #
    $test-> nextCase();
    #

    ###
    # Parser will ignore if a previous constance tag1 is tried to be parsed again, this is an feature.
    # So let's do tag2.
    ###
    $cnf->parse(undef,q(<<tag2<CONST>
    <HTML>something</HTML>
    >>));
    my $tag2 = $cnf->{tag2}; $tag2 =~ s/^\s*|\s*$//g; #<- trim spaces.
    $test->case($tag2);
    die $test->failed()  if not $tag2  eq '<HTML>something</HTML>';
    #

    #
    $test-> nextCase();
    #

    ###
    # Test central.cnf
    #
    ###
    die $test->failed()  if not  $cnf = CNFParser->new('./old/CNF2HTML.cnf');
    $test->case($cnf);
    $test->subcase("\$DEBUG=$cnf->{'$DEBUG'}");
    # CNF Constances can't be modifed anymore, let's test.
    try{
        $cnf->{'$DEBUG'}= 'false'
    }catch{
        $test->subcase("Passed keep constant test for \$cnf->\$DEBUG=$cnf->{'$DEBUG'}");
    }

    #
    $test->done();
    #
}
catch{ 
   $test -> dumpTermination($@);   
   $test->doneFailed();
}


