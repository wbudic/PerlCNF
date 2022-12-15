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

    
  $test->case("Test HTML Conversion.");
  $cnf = CNFParser->new(undef,
  {HTTP_HEADER=>q(
<!DOCTYPE html
PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
       "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US">
),
   DO_enabled=>1,ANONS_ARE_PUBLIC=>1
}
   ) -> parse    (undef,
  qq(

   <<PAGE<TREE>

     Title: Sample Web Page!
     <*<HEADER>*>

   [paragraph[
                  class:paragraph

   <img<         
      src:     tests/artifacts/PerlCNF.png         
   >img>

      [#[
               This is a Perl CNF to HTML example document.
               It similar to HTML that individual DOM elements.
               Are tree like placed in the body of the TREE instructed CNF Property.
               It is easier to the eye, and more readable. You can be the judge.

      ]#]

   ]paragraph]

     

   <div<
      class:paragraph      
      <div<
         <img< 
            src=tests/artifacts/PerlCNF.png 
            style=float:left
         >img>
         <div<              
              [p[
               [#[This sample is more in scheme HTML look alike.]#]
              ]p]  
         >div>
      >div>
   >div>


   >>

<<HEADER<TREE> _HAS_PROCESSING_PRIORITY_
[STYLE[
         [#[
            body {
               margin: 20px;
               text-align: center;
            }


            img {
               float: right;
               margin: 1px;
            }

            p {
            text-align: justify;
            padding-top: 50px;
            padding-left: 20px;
            padding-bottom: 50px;
            }

            .paragraph {
               float: none;
               width:  580px;	
               height: 280px;
               border-radius: 23%;
               border-radius: 23%;
               shape-outside: circle();
               background-color: antiquewhite;
               border: 1px solid black;
               margin-bottom: 5px;
            }
         ]#]
]STYLE]

     [CSS[
           [@@[jquery-ui.theme.css]@@]
           [@@[main.css]@@]
     ]CSS]

     [JS[
           [@@[main.js]@@]
     ]JS]
>>
   <<CNF_TO_HTML<PLUGIN>
    package     : HTMLProcessorPlugin
    subroutine  : convert
    property    : PAGE
   >>
)   
);
   my $ptr = $cnf->data();
   $ptr = $ptr->{'PAGE'};
   open my $fh, ">", "test.html";
   print $fh $$ptr;
   close $fh;

   #   
    $test->done();    
   #


}
catch { 
   $test -> dumpTermination($@);
   $test -> doneFailed();
}
