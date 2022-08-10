#!/usr/bin/env perl
use warnings; use strict; 
use lib "./tests";
use lib "./system/modules";

use lib "/home/will/dev/PerlCNF/tests";
use lib "/home/will/dev/PerlCNF/system/modules";

require TestManager;
use Syntax::Keyword::Try;


my $test = TestManager -> new($0);
my $cnf;

require CNFParser;

try{

   ###
   # Test instance creation.
   #
   die $test->failed() if not $cnf = CNFParser->new();
   $test->case("Passed new instance CNFParser.");
   $test->subcase('CNFParser->VERSION is '.CNFParser->VERSION);
   #  
   $test-> nextCase();
   #

   my $anons = $cnf->anon();
   die $test->failed() if %$anons; #The list is empty so far.
   $test->case("Obtained anons for repo.");
   #  
   $test-> nextCase();
   #
   $anons->{'The Added One'} = "Dynamically!";
   $cnf->anon()->{'The Added Two'} = "Dynamically2!";
   #  
   my $added = $cnf->anon('The Added One');
   $test->case("Added 'The Added One' ->$added");
   $test-> nextCase();
   die $test->failed() if not $added = $cnf->anon('The Added Two');
   $test->case("Added 'The Added Two' ->$added");   
   #

   #  
   $test-> nextCase();
   #

   ###
   # Anons are global by default.
   ###
   my $cnf2 = CNFParser->new();
   $added = $cnf2->anon('The Added Two');
   die $test->failed() if $cnf->anon('The Added Two') ne $cnf2->anon('The Added Two');
   $test->case("Contains shared 'The Added Two' ->$added");
   $test->subcase(CNFParser::anon('The Added One'));
   
   #  
   $test-> nextCase();
   #

   ###
   # Make anon's private for this one.
   ###
   my $cnf3 = CNFParser->new(undef,{ANONS_ARE_PUBLIC=>0});
   $added = $cnf3->anon('The Added Two');   
   die $test->failed() if $cnf3->anon('The Added Two');
   die $test->failed($cnf->anon('The Added Two')) if not $cnf->anon('The Added Two');
   $test->case("Doesn't contain a shared 'The Added Two'");
   $cnf3->anon()->{'The Added Three'} = "I am private Anon!";
   $test->subcase("It worked 'The Added Three = '".$cnf3->anon('The Added Three') );

   die $test->failed("main \$cnf contains:".$cnf->anon('The Added Three')) if  $cnf->anon('The Added Three');
   die $test->failed(    $cnf3 -> anon('The Added Three') ) if  $cnf3->anon('The Added Three') ne 'I am private Anon!';
   #
   $test-> nextCase();
   #

   ###
   # Test older cases v.2.4 compatibility.
   ##   
   testAnons();
   #
 
   #   
   $test->done();    
   #
}
catch{ 
   $test -> dumpTermination($@);   
   $test -> doneFailed();
}

#
#  TESTING THE FOLLOWING IS FROM HERE  #
#

sub testAnons {

# Anons are by default global, but script only of origin or settable by design.
# Not code. Hence their name.

CNFParser->new()->parse(undef,qq(
    <<one<1>>><<two<2>>>  <-- Is same as saying: {One=>1,Two=>2}.    <<1<THE_ONE>>>
));
# We hash to the global here, otherwise need to use in scalar context the variable like: my $anons = $obj->anon().
my %anons = %{CNFParser::ANONS};

my $cnf = CNFParser->new("databaseAnonsTest.cnf");
my $find = $cnf->anon('GET_SUB_URL',CNFParser->META);
die "Failed finding GET_SUB_URL" if not $find;
die "Missmatched found in GET_SUB_URL" if $find ne 'https://www.THE_ONE.acme.com/$$$2$$$';

# Let's try som JSON crap, lol.
$find = $cnf->anon('GET_SUB_URL',CNFParser->META_TO_JSON);
die "Failed finding GET_SUB_URL" if not $find;

# Test lifelog categories
my $v = $cnf->anon('CAT');
if(!$v) {die "CAT is Missing!"}
print "\n--- CAT ---\n".$v;


my $cmd = $cnf->anon('list_cmd', $ENV{'PWD'});
print "CMD is:$cmd\n";
$cmd = `$cmd`;
print "Error failed system command!" if !$cmd;
#print "Listing:\n$exe\n";

print "\n--LIST OF ALL ANONS ENCOUNTERED---\n";
foreach my $k (keys %anons){
    print "Key->$k=", $anons{$k},"]\n";
}
#eval((keys %anons) == 12) or die "Error annons count mismatch![".scalar(keys %anons)."]";

eval(length($cnf->constant('$HELP'))>0) or die 'Error missing multi-line valued constant property $HELP';

my $template = $cnf ->  template( 'MyTemplate', (
                                                'SALUTATION'=>'Mr',
                                                'NAME'=>'Prince Clington',
                                                'AMOUNT'=>"\$1,000,000",
                                                'CRITERIA'=>"Section 2.2 (Eligibility Chapter)"
                                )
                        );

print "\n--- TEMPLATE ---\n".$template;

### From the specs.
my $lst = ['tech','main.cgi'];
my $url = $cnf->anon('GET_SUB_URL', ['tech','main.cgi']);
# $url now should be: https://www.tech.acme.com/main.cgi
eval ($url =~ m/https:\.*/)
or warn "Failed to obtain expected URL when querying anon -> GET_SUB_URL";
eval ($url eq 'https://www.tech.acme.com/main.cgi') or die "Error with: $url";


}
