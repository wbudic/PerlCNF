###
# Meta flags that can be set for some CNF instructions.
###
package CNFMeta;

use strict;
use warnings;

###
# TREE instuction meta.
use constant  HAS_PRIORITY  => "HAS_PROCESSING_PRIORITY"; # Schedule to process before the rest in synchronous line of instructions.

#
###
# DO instruction meta.
#
use constant  ON_DEMAND      => "ON_DEMAND"; #Postpone to evaluate on demand.
use constant  SHELL          => "SHELL"; #Execute via system shell.

#

###
# Returns the regular expresion for any of this meta constances.
##
sub _meta {
    my $constance = shift;
    if($constance){
        return qr/\s*\_+$constance\_+\s*/
    }
    $constance;
}
###
# Priority order no. for instructions.
use constant PRIORITY => qr/(\s*\_+PRIORITY\_(\d+)\_+\s*)/o;
###
# Tree instruction has been scripted in collapsed nodes shorthand format.
# Shortife is parsed faster and with less recursion, but can be prone to script errors, 
# resulting in unintended placings.
use constant IN_SHORTIFE  => qr/(\s*\_+IN_SHORTIFE\_+\s*)/o;

sub import {     
    my $caller = caller;    no strict "refs";
    {
         *{"${caller}::meta"}  = \&_meta;
         *{"${caller}::meta_has_priority"}   = sub {return _meta(HAS_PRIORITY)};
         *{"${caller}::meta_priority"}       = \&PRIORITY;
         *{"${caller}::meta_on_demand"}      = sub {return _meta(ON_DEMAND)};
         *{"${caller}::meta_node_in_shortife"} =\&IN_SHORTIFE;
         *{"${caller}::SHELL"}  = \&SHELL;         
    }
    return 1;    
}

1;

=begin copyright
Programed by  : Will Budic
EContactHash  : 990MWWLWM8C2MI8K (https://github.com/wbudic/EContactHash.md)
Source        : https://github.com/wbudic/PerlCNF.git
Documentation : Specifications_For_CNF_ReadMe.md
    This source file is copied and usually placed in a local directory, outside of its repository project.
    So it could not be the actual or current version, can vary or has been modiefied for what ever purpose in another project.
    Please leave source of origin in this file for future references.
Open Source Code License -> https://github.com/wbudic/PerlCNF/blob/master/ISC_License.md
=cut copyright