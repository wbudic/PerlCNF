use warnings; use strict;
use 5.36.0;
use lib "tests";
use lib "system/modules";

require TestManager;
require CNFParser;

my $test = TestManager -> new($0);

use Syntax::Keyword::Try; try {   

    ###
    $test->case("Test CNF to JSON.");
 
    my $parser = CNFParser -> new(undef, {DO_ENABLED=>1})-> parse(undef, qq(
        <<SYS_DATE><DO>
            use POSIX qw(strftime);
            print strftime "%F", localtime;            
        >>
        <<SYS_OS<DO>return "$^O">>
        <<SYS_DATE<DO>`date`>>

            <<PROPERTIES   <TREE>
                date: <*<SYS_DATE>*>
                attr1 :one
                attr2 :' two'
                script:kid                
                <DATE<   
                    <*<SYS_DATE>*>  
                >DATE>
                [OS[
                    value:<*<SYS_OS>*>   
                ]OS]
                <boss<
                >boss>
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


    