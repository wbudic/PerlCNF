#!/usr/bin/env perl
use warnings; use strict; 
use Syntax::Keyword::Try;

use lib "./tests";
use lib "system/modules";

require CNFParser;
require TestManager;
my $test = TestManager -> new($0);
my $cnf;
try{  

   ###
   # Test instance creation.
   ###
   die $test->failed() if not $cnf = CNFParser->new();
       $test->case("Passed new instance CNFParser.");
       $test->subcase('CNFParser->VERSION is '.CNFParser->VERSION);
       ${$cnf->anon()}{Public} = 'yes';
       $test->evaluate('$cnf->anon(Public) == "yes"',$cnf->anon('Public'),'yes');
       $test->evaluate('$new->anon(Exclusive) == "yes"', CNFParser->new()->anon('Public'),'yes');
   #  
       $test-> nextCase();
   #

   ###
   # Test private instance config.
   ###
   my $private = CNFParser->new(undef,{Exclusive=>'yes', ANONS_ARE_PUBLIC=>0});
    $test->case("Test new private CNFParser.");
    $test->evaluate('$private->{Exclusive} is string "yes"?', $private->{Exclusive},'yes');
    $test->evaluate('$private->anon(Exclusive)?', $private->anon('Exclusive'),undef);
    $test->evaluate('$cnf->{Public} is still string "no"?', $cnf->anon('Public'),'yes');
    $test->evaluate('$private->{Public}', $private->anon('Public'),undef);    
    # Not defined as it isn't coming from an config file.
    $test->evaluate('Check $private->anon("Exlusive") is undef?',  $private->anon("Exclusive"),undef);
    $private->parse(undef,qq/<<test<best>>>/);
    $test->evaluate('Check $private->anon("test") is "best"?',  $private->anon("test"),'best');
    $test->evaluate('Check $cnf->anon("test") is undef?',  $cnf->anon("test"),undef);
    $test->subcase('new public #newInstance creation containing public assigned anon.');
    my $newInstance =CNFParser->new();
    $test->evaluate('Check $newInstance->anon("Exclusive") == $cnf->anon("Exclusive")?',  $newInstance->anon("Exclusive"), $private->anon("Exclusive"));
     ${$private->anon()}{Exclusive2} = 'yes';
    $test->case("Passed new private instance CNFParser.");

   #  
       $test-> nextCase();
   #

#CNFParser->new()->parse(undef,q(<<GET_SUB_URL<https://www.$$$1$$$.acme.com/$$$2$$$>>>));

# CNFParser->new()->parse(undef,qq(
# <<\$HELP<CONST
# Multiple lines
# in this text.
# >>>
# ));
# CNFParser->new()->parse(undef,q(<<GET_SUB_URL<https://www.$$$1$$$.acme.com/$$$2$$$>>>));

   my $anons = $cnf->anon();
   die $test->failed() if keys %$anons == 0; 
   my %h = %$anons;
   my $out; $out.="$_ => $$anons{$_}" for (keys %$anons);
   $test->case("Obtained \%anons{$out}");
   #  
   $test-> nextCase();
   #

   ###
   # List entry with non word instructions.
   ###
   CNFParser->new()->parse(undef,q(<<list$$<20.05$>Spend in supermarket.>>));
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


my $cnf = CNFParser->new("./old/databaseAnonsTest.cnf");
my $find = $cnf->anon('GET_SUB_URL',CNFParser->META);
die "Failed finding GET_SUB_URL" if not $find;
die "Missmatched found in GET_SUB_URL" if $find ne 'https://www.THE_ONE.acme.com/$$$2$$$';

# Let's try som JSON crap, lol.
$find = $cnf->anon('GET_SUB_URL',CNFParser->META_TO_JSON);
die "Failed finding GET_SUB_URL" if not $find;

# Test lifelog categories
my $v = $cnf->anon('CAT');
if(!$v) {die "CAT is Missing!"}
#print "\n--- CAT ---\n".$v;
die "CAT values proper data is missing!" 
if $v !~ m/90\|Fitness\s*\`Fitness steps, news, info, and useful links. Amount is steps.$/gm;

use Cwd;
my $cmd = $cnf->anon('list_cmd', [getcwd] );
print "CMD is:$cmd\n";
$cmd = `$cmd`;
die "Error failed system command!" if !$cmd;
#print "Listing:\n$exe\n";


# We hash to the global here, otherwise need to use in scalar context the variable like: my $anons = $obj->anon().
my %anons = %{CNFParser::ANONS};
die "annons not valis!" if not %anons;
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
die if $url !~ m/https:\.*/;
die if $url ne 'https://www.tech.acme.com/main.cgi';


}
