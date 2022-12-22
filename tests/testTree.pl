#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;

use lib "/home/will/dev/PerlCNF/tests";
use lib "/home/will/dev/PerlCNF/system/modules";


require TestManager;
require CNFParser;
require CNFNode;

my $test = TestManager -> new($0);
my $cnf;my $err;

try{

   ###
   # Test instance with cnf file creation.
   ###   
      $test->case("Check Tree Algorithm.");



my $for_html = q( 
   <div<
      <div<
         <div<
               [#[
                  This sample is more HTML look alike type of scheme.
               ]#]
         >div>
      >div>
   >div>
   [test[me too]test]
);

my $prp = CNFNode->new({name=>'TEST'})->process(CNFParser->new(),$for_html);
my $nested = $prp->find('div/div/div/#');
print "$nested\n";

my $nada = $prp->find('nada');
$test->isNotDefined("\$nada",$nada);
$nada = $prp->find('@$');
$test->isDefined("Name @\$ as property has subroperties",$nada);

   my $tree = q{
      [node[   
         a:1
         b=2
         [1[
            [#[Hello]#]
         ]1]
         [2[
            [#[ World! ]#]
         ]2]
      ]node]   
   };


   # my $tree = q{
   #    [node[
   #       [h1[ Hello World! ]h1]
   #    ]node]   
   # };

   #    my $tree = q{
   #    [node[   
   #       <div<
   #       a:1
   #          <div<
   #          b2:
   #          >div>
   #       >div>
   #    ]node]   
   # };
   
   my $property = CNFNode->new({name=>'TEST'})->process(CNFParser->new(),$tree);
   # my %node = %${node($node, 'node/1/2/3')};
   # print "[[".$node{'#'}."]]\n";
   
   # print "[[".%$$node{'#'}."]]\n";
   # $node = node($node, 'node/1/2/3/a');
   my $hello = $property->find('node/1/#');
   my $world  = $property->find('node/2/#');
   $test -> evaluate("[[$hello]]",$hello,'Hello');
   $test -> evaluate("[[$world]]",$world,' World! ');
      
    #
    $test->nextCase();  
    #

   $cnf = CNFParser->new()->parse(undef,qq(
   <<APP<My Nice Application by ACME Wolf PTY>>>
    <<DOC<TREE>
    a=1
    b:2
      [c[
            1:a
            2:barracuda
            [#[cccc]#]
      ]c]
   [*[APP]*]
    >>
));

   $test->case("Test parser parsing.");

   my $app = $cnf->anon('APP');

   my $doc = $cnf->anon('DOC');
   $test ->evaluate("\$doc->name() eg 'DOC'",$doc->name(),"DOC") ;
   my  $c = $doc->find('c');
   $test ->isDefined("doc/c", $c);    
   $test ->evaluate("Node 'DOC/c' eq 'cccc'", $c->val(), 'cccc');
   $test ->evaluate("App link is set", $doc->{APP},$app);

    #
    $test->nextCase();  
    #

   $test->case("Test find by path.");
   my $val = $doc->find('c/2');

   $test ->evaluate("Node 'DOC/c/2' eq 'barracuda'", $val, 'barracuda');


    #
    $test->nextCase();  
    #

    $test->case("Test Array parsing.");

    $tree = q{
      <node<
         [@@[On single line]@@]
         <@@<
            One value.
         ]@@]      
         [@@[
            Second value.
         ]@@]
         <prop<
                  some attribute = Something inbetween!
         >prop>
         [@@[
            Third value.
         ]@@] 
         [@@[
           
                        [p1[
                                 a:1
                                 b:2
                        ]/p1]
                        [#[ Fourth value. ]/#]
         ]@@]
      >node>
   };
   $property = CNFNode->new({name=>'TEST ARRAY'})->process($cnf,$tree);

   my $node  = $property->find('node/@@');
   $test->isDefined('node/@@', $node);
   $test->evaluate('node/@@', scalar(@$node),4);
   my $prop = $property->find('node/prop');
   $test ->isDefined('node/prop', $prop);  
   $test->evaluate('node/prop[{attribue}->val()', $prop->{'some attribute'}, 'Something inbetween!');
$cnf = CNFParser->new()->parse(undef,qq(
    <<DOC<TREE>
    a=1
    b:2
      [c[
            1:a
            2:barracuda
            [#[cccc]#]
      ]c]
    >>
));

  #
    $test->nextCase();  
  #


   

   #   
    $test->done();    
   #


}
catch { 
   $test -> dumpTermination($@);
   $test -> doneFailed();
}
