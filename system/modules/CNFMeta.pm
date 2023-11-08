# Meta flags that can be set for some CNF instructions.
# Programed by  : Will Budic
# Notice - This source file is copied and usually placed in a local directory, outside of its project.
# So it could not be the actual or current version, can vary or has been modiefied for what ever purpose in another project.
# Please leave source of origin in this file for future references.
# Source of Origin : https://github.com/wbudic/PerlCNF.git
# Documentation : Specifications_For_CNF_ReadMe.md
# Open Source Code License -> https://choosealicense.com/licenses/isc/
#
package CNFMeta;

use strict;
use warnings;

###
# Returns the regular expresion for any of the meta constances.
##
sub _meta {
    my $constance = shift;
    if($constance){
        return qr/\s*\_+$constance\_+\s*/
    }
    $constance;
}
#

###
# Priority order no. for instructions.
use constant PRIORITY => qr/(\s*\_+PRIORITY\_(\d+)\_+\s*)/o;

sub import {
    my $caller = caller;    no strict "refs";
    {

         # TREE instuction meta.
         *{"${caller}::meta_has_priority"}   = sub {return _meta("HAS_PROCESSING_PRIORITY")};
         # Schedule to process before the rest in synchronous line of instructions.
         *{"${caller}::meta_priority"}       = \&PRIORITY;
         #Postpone to evaluate on demand.
         *{"${caller}::meta_on_demand"}      = sub {return _meta("ON_DEMAND")};
         # Process or load last (includes0.
         *{"${caller}::meta_process_last"}   = sub {return _meta("PROCESS_LAST")};
         ###
         # Tree instruction has been scripted in collapsed nodes shorthand format.
         # Shortife is parsed faster and with less recursion, but can be prone to script errors,
         # resulting in unintended placings.
         *{"${caller}::meta_node_in_shortife"} = sub {return _meta("IN_SHORTIFE")};
         # Execute via system shell.
         *{"${caller}::SHELL"}  = sub {return _meta("SHELL")};
         # Returns the regular expresion for any of the meta constances.
         *{"${caller}::meta"}  = \&_meta;
    }
    return 1;
}
###
# CNF DATA instruction headers can contain extra expected data type meta info.
# This will strip them out and build the best expected SQL create table body, based on this meta.
# I know, this is crazy stuff, skips having to have to use the TABLE instruction in most cases.
###
sub _metaTranslateDataHeader {
    my $isPostgreSQL = shift;
    my @array = @_;
    my ($idType,$body,$primary)=('NONE');
    my ($INT,$BOOL,$TEXT,$DATE,$ID, $CNFID, $INDEX) = (
            _meta('INT'),_meta('BOOL'),_meta('TEXT'),_meta('DATE'),
            _meta('ID'),_meta('CNF_ID'),_meta('CNF_INDEX')
            );
    for my $i (0..$#array){
        my $hdr  = $array[$i];
        if($hdr eq 'ID'){
            if($isPostgreSQL){
               $body   .= "\"$hdr\" INT UNIQUE PRIMARY KEY GENERATED ALWAYS AS IDENTITY,\n";
               #$primary = "PRIMARY KEY(ID)"
            }else{
               $body   .= "\"$hdr\" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,\n";
            }
            # DB provited sequence, you better don't set this when inserting a record.
            $idType = 'AUTOINCREMENT'
        }elsif($hdr =~ s/$CNFID/""/ei){
            #This is where CNF provides the ID uinque int value (which doesn't have to be autonumbered i.e. '#', but must be unique).
            $body   .= "\"$hdr\" INTEGER NOT NULL PRIMARY KEY CHECK (\"$hdr\">0),\n";
            $idType = 'CNF_INDEX'
        }elsif($hdr =~ s/$ID/""/ei){
            #This is ID prefix to some other data id stored in this table, usually one to one/many relationship.
            $body   .= "\"$hdr\" INTEGER CHECK (\"$hdr\">0),\n";
        }elsif($hdr =~ s/$INDEX/""/ei){
            # This is where CNF instructs to make a indexed lookup type field,
            # for inside database fast selecting, hashing, caching and other queries.
            $body   .= "\"$hdr\" varchar(64) NOT NULL PRIMARY KEY,\n";
        }elsif($hdr =~ s/$INT/""/ei){
            $body   .= "\"$hdr\" INTEGER NOT NULL,\n";
        }elsif($hdr =~ s/$BOOL/''/ei){
            if($isPostgreSQL){
               $body   .= "\"$hdr\" BOOLEAN NOT NULL,\n";
            }else{
               $body   .= "\"$hdr\" BOOLEAN NOT NULL CHECK (\"$hdr\" IN (0, 1)),\n";
            }
        }elsif($hdr =~ s/$TEXT/""/ei){
            $body   .= "\"$hdr\" TEXT NOT NULL CHECK (length(\"$hdr\")<=2024),\n";
        }elsif($hdr =~ s/$DATE/""/ei){
            $body   .= "\"$hdr\" TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,\n";
        }else{
            $body   .= "\"$hdr\" TEXT NOT NULL,\n";
        }
        $array[$i] = $hdr;
    }
    if($primary){
        $body   .=  $primary;
    }else{
        $body =~ s/,$//
    }
return [\@array,\$body,$idType];
}
1;