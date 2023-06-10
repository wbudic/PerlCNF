use warnings; use strict;
use 5.36.0;
use lib "tests";
use lib "system/modules";

require TestManager;
require CNFParser;

my $test = TestManager -> new($0);

use Syntax::Keyword::Try; try {   

    ###
    $test->case("Test Do.");
 
    my $parser = CNFParser -> new(undef,{DO_ENABLED=>1});
       $parser->parse(undef,qq(
        #
        # LIB instruction is very  powerfull, it took me a while to figure out.
        # It loads the package based on file location or in form of a normal module declaration, which must available via the @INC paths.
        # Hence LIB instruction must be put at the begining of a config script file to load before a package is used.
        # This feature enables you also to specify now from a config file, which packages you use from CNF, 
        # and not to have to declared them in your perl source with use or require.
        #
            <<<LIB libs/LoadTestPackage.pm>>>
        #
            <<LoadTestPackage<DO>LoadTestPackage::tester();>>
            <<SYS_DATE<DO>`date`>>
            <<WARNINGS_SET<DO>              qq(hasWarnings:\$self->{ENABLE_WARNINGS})           >>

        ));
    my $sys_date = $parser->anon('SYS_DATE');
        $test -> isDefined("\$sys_date:$sys_date",$sys_date);
        $test -> isDefined("\$WARNINGS_SET:".$parser->anon('WARNINGS_SET'),$parser->anon('WARNINGS_SET'));
    #

    #
    $test->nextCase();  
    #

    $test->case("Test Lib loading.");
        my $last_lib = $parser->anon('LAST_LIB');
        $test -> isDefined("\$last_lib:$last_lib",$last_lib);
        my $LoadTestPackage = $parser->anon('LoadTestPackage');
        $test -> isDefined("\$LoadTestPackage:$LoadTestPackage",$LoadTestPackage);
        $test -> evaluate("\$LoadTestPackage value.",'Hello World!',$LoadTestPackage);
        ###
        $test->subcase("Test if we can create a ghost object?");
            my $ghost = $last_lib -> new();
            $test -> isDefined("\$ghost", $ghost);
            $test -> evaluate("ghost is comming from?",$ghost->{'Comming from where?'},"out of thin air!");

    #
    $test->done();
    #
}
catch{ 
   $test -> dumpTermination($@);
   $test->doneFailed();
}


    