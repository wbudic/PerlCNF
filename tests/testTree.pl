#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;

use lib "./tests";
use lib "/home/will/dev/PerlCNF/system/modules";


require TestManager;
require CNFParser;
require CNFNode;

my $test = TestManager -> new($0);
my $cnf;

try{

   ###
   # Test instance with cnf file creation.
   ###   
      $test->case("Check Tree Algorithm.");

      my $tree = q{
      [node]   
         a:1
         b=2
         [1]
            [#]Hello[/#]
         [/1]
         [2]
            [#]World![/#]
         [/2]
      [/node]   
   };
   
   my $property = CNFNode->new({name=>'TEST'})->process($tree);
   # my %node = %${node($node, 'node/1/2/3')};
   # print "[[".$node{'#'}."]]\n";
   
   # print "[[".%$$node{'#'}."]]\n";
   # $node = node($node, 'node/1/2/3/a');
   my $hello = $property->find('node/1/#');
   my $node  = $property->find('node/2/#');
   print "2->[[$$hello $$node]]\n";
      
    #
    $test->nextCase();  
    #

   $cnf = CNFParser->new()->parse(undef,qq(
    <<DOC<TREE>
    a=1
    b:2
      [c]
            1:a
            2:barracuda
            [#]cccc[/#]
      [/c]
    >>
));

   $test->case("Test parser parsing.");

   my $doc = $cnf->anon('DOC');
   $test ->evaluate("\$doc->name() eg 'DOC'",$doc->name(),"DOC") ;
   $test ->isDefined("doc/c", $doc->{'c'});
   $test ->evaluate("Node 'DOC/c' eq 'cccc'", $doc->{'c'}->val(), 'cccc');

    #
    $test->nextCase();  
    #

   $test->case("Test find by path.");
   my $val = $doc->find('c/2');

   $test ->evaluate("Node 'DOC/c/2' eq 'barracuda'", $$val, 'barracuda');

    #   
    $test->done();    
    #
}
catch{ 
   $test -> dumpTermination($@);   
   $test -> doneFailed();
}
