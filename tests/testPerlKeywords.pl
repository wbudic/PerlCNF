#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;

use lib "tests";
use lib "system/modules";
use PerlKeywords qw(%KEYWORDS %FUNCTIONS &matchForCSS &CAP &span_to_html);

use TestManager;



my $test = TestManager -> new($0);
my $cnf;

try{

    $test->case("Regex as string.");
    my $regex = qr/\s*#.*$/o;
    my $match = '# text';
    if($match =~ $regex){
        $test -> passed("Regex match -> [$match]")
    }else{
        $test -> failed("Regex match -> [$match]")
    }
    $regex = qr/(['"])(.*)(['"])/s;
    $match = 'word \'text\'';
    if($match =~ $regex){
        $test -> passed("Regex match -> [$match] found: [$1],[$2],[$3]")
    }else{
        $test -> failed("Regex match -> [$match]")
    }
    $test->case("KEYWORDS access.");
        $test->isDefined('bless', $KEYWORDS{'bless'});
        $test->isDefined('my', $KEYWORDS{'my'});
    $test->case("Functions access.");
        $test->isDefined('print', $FUNCTIONS{'print'});
        $test->isDefined('getprotobynumber', $FUNCTIONS{'getprotobynumber'});
    
    #  
    $test-> nextCase();
    #

    ###   
    # Test regular expression if matching.
    $test->case("Test matchForCSS.");
        $test->evaluate("'comments' eq matchForCSS('\# text') ?","comments", matchForCSS('   # text'));
        if($2 eq'text'){ $test -> passed("main::Regex last match still is -> [$2]") }else{ $test -> failed("Regex match -> \$2") }
        if(@{CAP()}[0] eq '   # text'){ $test -> passed("Regex last match is -> ['   # text']") }else{ $test -> failed("Regex match -> '   # text'") }
    #
    ###   
    # Test transforming.
    $test->case("Test code to html transforming.");
    my $gender= q(my $sex = 'male';);
    my $trans = span_to_html($gender);
    print $$trans;
    $test->evaluate("html transformation matches?", $$trans, qq(<span class="K">my</span>&nbsp;<span class="V">\$sex</span>&nbsp;<span class="O">= '</span><span class="male</span><span class="Q">'</span><span class="O">;</span><br>\n));
    

    #   
    $test->done();    
    #
}
catch{ 
   $test -> dumpTermination($@);   
   $test -> doneFailed();
}



