use warnings; use strict;
use 5.36.0;
use lib "system/modules";
use lib "tests";

require TestManager;
require ShortLink;

my $test = TestManager->new($0);
use Syntax::Keyword::Try; try{ 

    $test->case("List generation.");

my $pickOne;
my @docs = glob('~/Pictures/*.*');
foreach my $path(@docs){
say 
    ShortLink::obtain($path),":",$path;
$pickOne = $path if rand(10) > 8
}

say "Picked:$pickOne having code:".ShortLink::existing($pickOne);

$test->done();


# use MIME::Base64;
# my $text = "local/HTMLProcessorPlugin.pm";
# # use Compress::Zlib;
# # my $cmp = compress($text);
# # my $ec  = encode_base64($cmp);
# # say "cmp[".length($ec)."]:". $ec;
# # my $ucp = uncompress($cmp);
# # say "ucp[".length($ucp)."]:".$ucp;

# say 'IO next';

# my $oec = encode_base64($text);
# say "oec[".length($oec)."]:".$oec;

# use IO::Compress::Deflate qw(deflate $DeflateError);

# my $output;
# deflate \$text => \$output or die "gzip failed: $DeflateError\n";

# my $enc = encode_base64($output);
# say "enc[".length($enc)."]:".$enc;
# my $dec = decode_base64($enc);
# say "dec[".length($dec)."]:".$dec;

# use IO::Uncompress::Inflate qw(inflate $InflateError);
# my $decomp;
# inflate \$dec => \$decomp or die "inflate failed: $InflateError\n";
# say "dcp[".length($decomp)."]:".$decomp;


# use IO::Compress::Xz qw(xz $XzError) ;
 
#  my $outxz;
# xz \$text=> \$outxz  or die "xz failed: $XzError\n";
# my $xenc = encode_base64($outxz);
# say "xenc[".length($xenc)."]:".$xenc;
# my $xdec = decode_base64($xenc);
# say "xdec[".length($xdec)."]:".$xdec;

# use IO::Uncompress::UnXz  qw(unxz $UnXzError) ;
# my $xdecomp;
# unxz \$xdec => \$xdecomp or die "inflate failed: $InflateError\n";
# say "dcp[".length($xdecomp)."]:".$xdecomp;

}
catch{ 
   $test -> dumpTermination($@);
   $test->doneFailed();
}