#!/usr/bin/env perl
use warnings; use strict;
use Syntax::Keyword::Try;

use lib "tests";
use lib "system/modules";


require TestManager;
require CNFParser;

my $test = TestManager -> new($0);
my $cnf;

try{

   ###
   # Test instance with cnf a file.
   ###
   die $test->failed() if not $cnf = CNFParser->new('./tests/example.cnf',{ENABLE_WARNINGS=>0});
       $test->case("Passed new instance CNFParser.");
       $test->subcase('CNFParser->VERSION is '.CNFParser->VERSION);
       $test->subcase('$cnf->{\'$IMMUTABLE\'} is '.$cnf->{'$IMMUTABLE'});
       $test->evaluate('$IMMUTABLE == "Hello World! "',$cnf->{'$IMMUTABLE'},'Hello World! ');

       $test->subcase('Test undeclared constance access!');
       try{
         my $immutable = $cnf->{IMMUTABLE};
         $test->failed("Failed access allowed to undefined constances.")
       }catch{
         $test->passed("It errored, trying to access undeclared constance.");
       }

       $test->subcase('Resolve undeclared constance access!');
       try{
         my $immutable = $cnf->const('IMMUTABLE');
         $test->passed("Passed to access constance with variable resolve.");
         $test->isDefined('$FRENCH_PARAGRAPH',$immutable);
       }catch{
         $test->failed("Failed access allowed to undefined constances.")
       }
   #
   ###
       $test->subcase("Test constance's instructed block.");
       my $samp = $cnf->{'$TITLE_HEADING'};
       $test->evaluate('$TITLE_HEADING', $samp, 'Example Application');
       $samp = $cnf->{'$FRENCH_PARAGRAPH'};
       $test->isDefined('$FRENCH_PARAGRAPH',$samp);
       $samp = $cnf->const('$CLINGTON_PARAGRAPH');
       $test->isNotDefined('$NONE_EXISTANT',$samp);
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

    die $test->failed() if not $cnf = CNFParser->new('./tests/example.cnf',{'$DYNAMIC_IMMUTABLE'=>'app assigned constant value',ENABLE_WARNINGS=>0});
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
    $test->nextCase();
    #


    ###
    # Test DATA instuctions and Plugin powers of PCNF.
    ###
   die $test->failed() if not $cnf = CNFParser->new('./tests/example.cnf', {
            DO_ENABLED=>1,       # Disabled by default. Here we enable as we are using an plugin.
            ANONS_ARE_PUBLIC=>1, # Anon's are shared and global for all of instances of this object, by default.
            ENABLE_WARNINGS=>1   #
        });
       $test->case("Passed -> new instance CNFParser with DO_ENABLE set.");

      my $data = $cnf->anon('ACME_SAMPLE_StaffTable');
       $test->isNotDefined('ACME_SAMPLE_StaffTable',$data);
       $data = %{$cnf->data()}{'ACME_SAMPLE_StaffTable'};
       $test->isDefined('ACME_SAMPLE_StaffTable',$data);
       # It is multi dimensional array and multi property stuff.
       print "## ACME_SAMPLE_StaffTable Members List\n";
       foreach (@$data[0]){
         my @rows = @$_;
         foreach(@rows){
            my @cols = @$_;
            print $cols[1]."\t\t $cols[2]\n";
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

