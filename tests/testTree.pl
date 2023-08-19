#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;

use lib "tests";
use lib "system/modules";


require TestManager;
require CNFParser;
require CNFNode;

my $test = TestManager -> new($0);
my $cnf;my $err;

try{

   $test->case("Test nested multiline value.");
   my $property = ${CNFNode->new({name=>'TEST'})->process(CNFParser->new(), qq(           
         [a[
           [b[
                      [#[
                        1
                        2
                        3

                      ]#]
           ]b]           
         ]a]
         [cell[
            [#[
                <img src="images/PerlCNF.png" style="float:left"/>
                <a name="top"></a><a href="#bottom">To Bottom</a>
            ]#]            
         ]cell]      
   ))};
   
   my $prp = $property->find('cell');
   $test ->isDefined('cell', $prp);
   print $prp->val();
   $prp = $property->find('a/b');
   $test ->isDefined('a/b', $prp);
   $test ->evaluate('a/b=1\n2\n3\n', $prp->val(),"1\n2\n3\n"); 
   #

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
         <div<
               [#[
                  Other text
               ]#]
         >div>
      >div>
   >div>
   [test[me too]test]
);

$prp = ${CNFNode->new({name=>'TEST'})->process(CNFParser->new(),$for_html)};
my $nested = $prp->find('div/div/div/[0]/#');
$test->evaluate("div/div/div/{0}/#",$nested,"This sample is more HTML look alike type of scheme.");

my $nada = $prp->find('nada');
$test->isNotDefined("\$nada",@$nada);
$nada = $prp->find('@$');
$test->isDefined("TEST/@\$ properties subroperties",$nada);
$nada = $prp->find('test/#');
$test->evaluate("\$TEST/test",$nada,'me too');





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
    my $tree = q{
      [node[   
         a:1
         b=2
         [1[
            [#[Hello ]#]
            [#[
               my

            ]#]
         ]1]
         [2[
            [#[ World! ]#]
         ]2]
      ]node]   
   };
   $property = ${CNFNode->new({name=>'TEST'})->process(CNFParser->new(),$tree)};
   # my %node = %${node($node, 'node/1/2/3')};
   # print "[[".$node{'#'}."]]\n";
   
   # print "[[".%$$node{'#'}."]]\n";
   # $node = node($node, 'node/1/2/3/a');
   my $hello = $property->find('node/1/#');
   my $world  = $property->find('node/2/#');
   $test -> evaluate("[[$hello]]",$hello, "Hello my\n"); #<- nl is simulated, not automaticaly assumed with multi values taged
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

   $test->case("Test parser parsing.");                                                #3

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

   $test->case("Test find by path.");                    #4
   my $val = $doc->find('c/2');

   $test ->evaluate("Node 'DOC/c/2' eq 'barracuda'", $val, 'barracuda');


    #
    $test->nextCase();  
    #

    $test->case("Test Array parsing.");                  #5

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
                        ]p1]
                        [#[ Fourth value. ]#]
         ]@@]
      >node>
   };
   
   # $tree = q{
   #    <node< 
   #       [@@[
   #                      [p1[
   #                               a:1
   #                               b:2
   #                      ]p1]
   #                      [#[ Fourth value. ]/#]
   #       ]@@]
   #       [@@[
   #                      [p2[
   #                               aa:1
   #                               b:2
   #                      ]/p2]                        
   #       ]@@]
   #    >node>
   # };
   
   $property = ${CNFNode->new({name=>'TEST ARRAY'})->process($cnf,$tree)};

   my $node  = $property->find('node/@@');
   $test->isDefined('node/@@', $node);
   $test->evaluate('node/@@', scalar(@$node),5);
   my $prop = $property->find('node/prop');
   $test ->isDefined('node/prop', $prop);  
   $test->evaluate('node/prop[{attribue}->val()', $prop->{'some attribute'}, 'Something inbetween!');
   
   $node  = $property->find('node/@@/p1');
   $test->isDefined('node/@@/p1', $node);
   $val  = $property->find('node/@@/p1/b');
   $test->isDefined('node/@@/p1/b', $val);
   $test->evaluate('node/@@/p1/b', $val, '2' );

 

   #   
    $test->done();    
   #


}
catch { 
   $test -> dumpTermination($@);
   $test -> doneFailed();
}
