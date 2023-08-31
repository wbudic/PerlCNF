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

use constant{
                FORMAT         => '%Y-%m-%d %H:%M:%S',
                FORMAT_NANO    => '%Y-%m-%d %H:%M:%S.%3N %Z',
                FORMAT_SCHLONG => '%A, %d %B %Y %H:%M:%S %Z'
};

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
    usleep(1_028_69);
    $self->{timestamp} = $self->datetime() -> strftime(FORMAT_NANO)
}
sub toTimestampShort($self) {
    return $self->{timestamp} if exists $self->{timestamp};
    usleep(1_028_69);
    $self->{timestamp} = $self->datetime() -> strftime(FORMAT)
}
sub toSchlong($self){
    return $self->{long} if exists $self->{long};
    $self->{long} = $self->datetime() -> strftime(FORMAT_SCHLONG)
}
sub _toCNFDate ($formated, $timezone) {
    my $dt = DateTime::Format::DateParse->parse_datetime($formated, $timezone);
    return newSet('CNFDateTime',{epoch => $dt->epoch, datetime=>$dt, TZ=>$timezone});
}
sub _listAvailableCountryCodes(){
     require DateTime::TimeZone;
     return  DateTime::TimeZone->countries();
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
Implementing the DateTime module with local libraries, was always problematic at some stages
as the Perl build or running environment changes.

It is huge and in minimal form usually delivered with default basic or minimal Perl setups.
It in full provides the most compressive list of world locales and timezones possibilities.
This means language translations and many other, formats of date outputs based on the locale expected look.

PerlCNF doesn't need it in reality as has its own fixed format to accept and produce.
PerlCNF must also support world timezones.

Hence it needs DateTime, and some of its modules to provide its timezone string and convert it back and forth.
Other, DateTime::Format::DateParse, module itself is small, compared to the DateTime module.

Without proper dev. tools and what to look for, it is very hard to figure out what is going on, that things fail.
For example at the production site. But not on the development setup.

2023-08-23

On occasions DateTime in the past, since 5 eight years to this day, it would lib error crash the whole Perl running environment.
Something veryhard to find and correct also to forsure test on various installations.
For these and other reasons, the PerlCNF datetime format was avoided from being implemented or needed.

However, CNFDateTime in its first inclination attempts again to encapsulate this long time due functionality of requirements.
Came to life in the final of PerlCNF v.2.9, along with the new PerlCNF instruction DATE, of the release.

TestManager has also now been updated to capture any weird and possible Perl underlying connectors to libraries,
which are of no concern what so ever to the actual local code being tested.

=cut history