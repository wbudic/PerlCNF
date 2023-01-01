
package ShortLink;
use 5.36.0;
use warnings; use strict;

use Math::Base::Convert qw(dec b64);

our $CNT = 0;
our $CNV = Math::Base::Convert->new(dec, b64);
our %LINKS = ();
our %PATHS = ();

sub obtain($path){   
    if($path){
        return  $PATHS{$path} if exists $PATHS{$path};    
        my $key       = $CNV->cnv(++$CNT);
        $LINKS{$key}  = $path; 
        $PATHS{$path} = $key;
        return $key
    }
    die "You f'ed Up!"
}

sub existing($path){    
    return $PATHS{$path};
}

sub convert($key){
    return $LINKS{$key}
}

return 1;