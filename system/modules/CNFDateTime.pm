###
# CNFDateTime objects provide conversions from script to inbuild Perls localtime function using high precision.
# They are lightly initilized, compared to using DateTime directly.
#
package CNFDateTime;
use strict;
use warnings;
use Time::HiRes qw(time);
use DateTime;
use DateTime::Format::DateParse;

sub new {
    my ($class,$settings)=@_;
    $settings = {} if not defined $settings;
    $settings-> {epoch} = time if not exists $settings->{epoch};
    return bless bless $settings, $class
}

sub datetime() {
    my $self = shift;    
       return $self->{datetime} if exists $self->{datetime};
    my $dt = DateTime->from_epoch($self->{epoch});
    $dt->set_timezone($self->{TZ}) if $self->{TZ};
    $self->{datetime} = $dt
}

sub toTimestamp{
    my $self = shift;
    return $self->{timestamp} if exists $self->{timestamp};
    $self->{datetime} = DateTime->from_epoch($self->{epoch}) if not exists $self->{datetime};
    $self->{timestamp} = $self->{datetime} -> strftime('%Y-%m-%d %H:%M:%S.%3N')
}
sub _toCNFDate{
    my ($formated,$timezone) = @_;
    my $dt = DateTime::Format::DateParse->parse_datetime($formated, $timezone);
    return CNFDateTime->new({epoch => $dt->epoch, datetime=>$dt, TZ=>$timezone});    
}



1;

# Programed by  : Will Budic
# Notice - This source file is copied and usually placed in a local directory, outside of its project.
# So it could not be the actual or current version, can vary or has been modiefied for what ever purpose in another project.
# Please leave source of origin in this file for future references.
# Source of Origin : https://github.com/wbudic/PerlCNF.git
# Documentation : Specifications_For_CNF_ReadMe.md
# Open Source Code License -> https://choosealicense.com/licenses/isc/