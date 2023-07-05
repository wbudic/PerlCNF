use warnings; use strict;
use lib "tests";
use lib "system/modules";

require TestManager;
require CNFParser;

my $test = TestManager -> new($0);

use Syntax::Keyword::Try; try {   

    ###
    $test->case("Test CNF to JSON.");
 
    my $parser = CNFParser -> new(undef, {DO_ENABLED=>1}) -> parse(undef, qq(
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
                # empty property is allowed.
                <boss<
                >boss>
                <LIST<
                    [@@[One]@@]
                    [@@[owT]@@]
                    [@@[Three]@@]
                >LIST>
            >>

        # Annon for the TREE is Collapsed.
        <<<TREE
                <Collapsed< __IS_COLLAPSED__
                                Paths __\
                                    attr1: test
                                    ele = some value__\
                                 List__/
                >Collapsed>
                <Uncollapsed<
                                <Paths<
                                    attr1:test
                                    <ele<
                                            <#<some value>#>
                                    >ele>
                                    [List[                                        
                                    ]List]
                                >Paths>
                >Uncollapsed>
        >>>

        ));
    my $properties = $parser->anon('PROPERTIES');
       $test -> isDefined("\$properties",$properties); 
       my $boss = $properties->node('boss');
       $test -> isDefined("\$boss",$boss); 
       $test -> evaluate('$boss=""',$boss->val(),"");
       my $json = $parser->JSON()->nodeToJSON($properties);
       #print $$json,"\n";
       my $cnf = $parser ->JSON()->jsonToCNFNode($$json);
       if($cnf  -> equals($properties)){
          $test -> passed("JSON conversion forth and back.");
       }else{
          $test -> failed("JSON conversion forth and back.");
       }
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


    