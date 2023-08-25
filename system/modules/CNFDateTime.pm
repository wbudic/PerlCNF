###
# CNFDateTime objects provide conversions from script to high precision time function not inbuild into perl interpreter.
# They are lightly initilized, compared to using DateTime directly, so this is not merely a wrapper around DateTime.
#
package CNFDateTime;
use strict;
use warnings;
use Time::HiRes qw(gettimeofday);
use DateTime;
use DateTime::Format::DateParse;

sub new {
    my ($class,$settings)=@_;
    $settings = {} if not defined $settings;
    $settings-> {epoch} = gettimeofday if not exists $settings->{epoch};
    return bless bless $settings, $class
}

sub datetime() {
    my $self = shift;    
       return $self->{datetime} if exists $self->{datetime};
       $self->{epoch} = time if not defined $self->{epoch};
    my $dt = DateTime->from_epoch(int($self->{epoch}));
    $dt->set_timezone($self->{TZ}) if $self->{TZ};
    $self->{datetime} = $dt
}

sub toTimestamp{
    my $self = shift;
    return $self->{timestamp} if exists $self->{timestamp};
    $self->{datetime} = datetime() if not exists $self->{datetime};
    $self->{timestamp} = $self->{datetime} -> strftime('%Y-%m-%d %H:%M:%S.%3N')
}
sub toSchlong{
    my $self = shift;
    return $self->{long} if exists $self->{long};
    $self->{datetime} = datetime() if not exists $self->{datetime};
    $self->{long} = $self->{datetime} -> strftime('%A, %d %B %Y %H:%M:%S %Z')
}
sub _toCNFDate{
    my ($formated,$timezone) = @_;
    my $dt = DateTime::Format::DateParse->parse_datetime($formated, $timezone);
    return CNFDateTime->new({epoch => $dt->epoch, datetime=>$dt, TZ=>$timezone});    
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