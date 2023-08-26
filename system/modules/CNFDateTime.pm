###
# CNFDateTime objects provide conversions from script to high precision time function not inbuild into perl interpreter.
# They are lightly initilized, compared to using DateTime directly, so this is not merely a wrapper around DateTime.
#
package CNFDateTime;
use strict;
use warnings;
use DateTime;
use DateTime::Format::DateParse;
use Time::HiRes qw(time usleep);
use feature 'signatures';

sub new($class){
    return newSet($class,{});
}
sub newSet($class, $settings){    
    $settings->{epoch} = time if not exists $settings->{epoch};
    return bless $settings, $class
}
sub datetime($self) {
    return $self->{datetime} if exists $self->{datetime};
    #   $self->{epoch} = time if not defined $self->{epoch};
    my $dt = DateTime->from_epoch($self->{epoch});
       $dt->set_time_zone($self->{TZ}) if $self->{TZ};
    $self->{datetime} = $dt;
    return $dt
}
sub toTimestamp($self) {    
    return $self->{timestamp} if exists $self->{timestamp};
    usleep(1_000_000);
    $self->{timestamp} = $self->datetime() -> strftime('%Y-%m-%d %H:%M:%S.%3N')
}
sub toSchlong($self){
    return $self->{long} if exists $self->{long};    
    $self->{long} = $self->datetime() -> strftime('%A, %d %B %Y %H:%M:%S %Z')
}
sub _toCNFDate ($formated, $timezone) {
    my $dt = DateTime::Format::DateParse->parse_datetime($formated, $timezone);
    return newSet('CNFDateTime',{epoch => $dt->epoch, datetime=>$dt, TZ=>$timezone});    
}
sub _listAvailableCountryCodes(){
     require DateTime::TimeZone;
     return DateTime::TimeZone->countries();
}
sub _listAvailableTZ($country){
     require DateTime::TimeZone;
     return  length($country)==2?DateTime::TimeZone->names_in_country( $country ):DateTime::TimeZone->names_in_category( $country );
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

=begin history

=cut history