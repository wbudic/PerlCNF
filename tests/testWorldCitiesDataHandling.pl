#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;

use lib "./tests";
use lib "system/modules";

require TestManager;
require CNFParser;

my $test = TestManager -> new($0);
my $cnf;

try{

   ###
   # Test instance cnf file loading time.
   ###
   $test->case("Loading ./tests/world_cities.cnf.")->start();
   die $test->failed() if not $cnf = CNFParser->new('./tests/world_cities_tmp.cnf',{DO_ENABLED=>1,ENABLE_WARNINGS=>1});
   $test->stop();
       

    #
    $test->nextCase();  
    #


    $test->case("Obtain and display World Cities data.");
    my $data = $cnf->data()   ->
                    {'WorldCities'};
    $test->isDefined('WorldCities',$data);

   foreach(@$data){
      foreach(@$_){
         my @col = @$_;             
         print qq($col[0] \t\t $col[3]\n);             
      }
   }

   $test->case("Select raw CNF data format from file.");
   
      my $cnt =0;
      my @data2 = %{$cnf->data()}
                      {'World_Cities_From_Data_File'};                      
      $test->isDefined('World_Cities_From_Data_File',@data2);
      foreach(@data2){
         if(ref($_) eq 'ARRAY'){            
            foreach(@$_){
               my @col = @$_;
               print $col[0]."\t\t $col[3]\n";
               last if $cnt++>5
            }            
         }
      }
      $test->case("Do an select based on domain.");
      $cnt =0;
      foreach($data2[1]){         
         foreach(@$_){
            my @col = @$_;
            if($col[4] eq 'AU'){
               print $col[0]."\t\t $col[3]\n";
               last if $cnt++>5
            }
         }
      } 

    #   
    $test->done();    
    #
}
catch{ 
   $test -> dumpTermination($@);   
   $test -> doneFailed();
}

