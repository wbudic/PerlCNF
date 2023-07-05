use warnings; use strict;
use 5.36.0;
use lib "tests";
use lib "system/modules";

require TestManager;
require CNFParser;
require CNFMeta; CNFMeta->import();

my $test = TestManager -> new($0);

use Syntax::Keyword::Try; try {   

    ###
    $test->case("Test CNFMeta regexp directly.");
    my $val = "   __PRIORITY_1_____TEST";
    my $reg = meta_priority();
    my $priority = ($val =~ s/$reg/""/sexi);
    $test -> isDefined("\$priority:$1",$2); 
    $test -> isDefined("\$2==$2",$2);
    $test -> evaluate("\$val is 'TEST'?",$val,"TEST"); 

    $reg =  meta_has_priority();
        $test->subcase("Test -> $reg");
        $val ="TEST2 ____HAS_PROCESSING_PRIORITY_______";
        $priority = ($val =~ s/$reg/""/sexi);
        $test -> isDefined("\$priority:$priority \$val='$val'",$val); 
        $test -> evaluate("\$val is 'TEST2'?",$val,"TEST2"); 
    #
    $test->nextCase();  
    #        
    $test->case("Test CNFMeta regexp directly.");

 
    my $parser = CNFParser -> new(undef, {DO_ENABLED=>1})-> parse(undef, qq(
        <<SYS_DATE><DO>
            use POSIX qw(strftime);
            print strftime "%F", localtime;            
        >>
        <<SYS_OS<DO>return "$^O">>
        <<SYS_DATE<DO>____PRIORITY_1_`date`>>

        <<A<TREE> _PRIORITY_2_
        >>
        <<B<TREE> _PRIORITY_1_
        #Should be first property in list, named B otherwise would be first as it goes in a hash of instructs, 
        #and all are seen unique names, allowing overides for of annons..
        >>

            <<PROPERTIES   <TREE> _PRIORITY_28_
                date: <*<SYS_DATE>*>
            >>

        ));
    my $props = $parser->anon('PROPERTIES');
       $test -> isDefined("\$props",$props); 
       my $json = $parser->JSON()->nodeToJSON($props);
       print $$json,"\n"; 
    #
    $test->nextCase();  
    #

    #
    $test->done();
    #
}
catch{ 
   $test -> dumpTermination($@);
   $test->doneFailed();
}


    