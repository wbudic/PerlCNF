package DataProcessorPlugin;

use strict;
use warnings;

use feature qw(signatures);
use Scalar::Util qw(looks_like_number);
use Date::Manip;
use Clone qw(clone);

use constant VERSION => '1.0';

sub new ($class, $plugin){
    my $settings;
    if($plugin){
       $settings = clone $plugin; #clone otherwise will get hijacked with blessings.
       $settings->{Language}='English' if not exists $settings->{Language};
       $settings->{DateFormat}='US'    if not exists $settings->{DateFormat}
    }else{
       $settings = {Language=>'English',DateFormat=>'US'}
    }
    Date_Init("Language=".$settings->{Language},"DateFormat=".$settings->{DateFormat}); #<-- Hey! It is not mine fault, how Date::Manip handles parameters.
    return bless $settings, $class
}

###
# Process config data to contain expected fields and data.
###
sub process ($self, $parser, $property) {
    my @data = $parser->data()->{$property};
#
# The sometime unwanted side of perl is that when dereferencing arrays,
# modification only is visible withing the scope of the block.
# Following processes and creates new references on modified data.
# And is the reason why it might look ugly or has some unecessary relooping.
#
    for my $did (0 .. $#data){
        my @entry = @{$data[$did]};
        my $ID_Spec_Size = 0;
        my @SPEC;
        my $mod = 0;
        # Cleanup header label row for the columns, if present.
        foreach (@entry){
            my @row = @$_;
            $ID_Spec_Size = scalar @row;
            for my $i (0..$ID_Spec_Size-1){
                if($row[$i] =~ /^#/){
                    $SPEC[$i] = 1;
                }
                elsif($row[$i] =~ /^@/){
                    $SPEC[$i] = 2;
                }
                else{
                    $SPEC[$i] = 3;
                }
            }
            if($row[0]){
                shift @entry;
                last
            }
        }
        for my $eid (0 .. $#entry){
            my @row = @{$entry[$eid]};
            if ($ID_Spec_Size){
                # If zero it is presumed ID field, corresponding to row number + 1 is our assumed autonumber.
                if($row[0] == 0){
                    my $size = @row;
                    $size = length(''.$size);
                    $row[0] = zero_prefix($size,$eid+1);
                    $mod = 1
                }
                if(@row!=$ID_Spec_Size){
                    warn "Row data[$eid] doesn't match expect column count: $ID_Spec_Size\n @row";
                }else{
                    for my $i (1..$ID_Spec_Size-1){
                        if(not matchType($SPEC[$i], $row[$i])){
                            warn "Row in row[$i]='$row[$i]' doesn't match expect data type, contents: @row";
                        }
                        elsif($SPEC[$i]==2){
                               my $dts = $row[$i];
                               my $dt  = UnixDate(ParseDateString($dts), "%Y-%m-%d %T");
                               if($dt){ $row[$i] = $dt; $mod = 1 }else{
                                  warn "Row in row[$i]='$dts' has imporper date format, contents: @row";
                               }
                        }
                    }
                }
                $entry[$eid]=\@row if $mod; #<-- re-reference as we changed the row. Something hard to understand.
            }
        }
        $data[$did]=\@entry if $mod;
    }
    $parser->data()->{$property} = \@data;
}
sub zero_prefix ($times, $val) {
    return '0'x$times.$val;
}
sub matchType($type, $val, @rows) {
    if   ($type==1 && looks_like_number($val)){return 1}
    elsif($type==2){
          if($val=~/\d*\/\d*\/\d*/){return 1}
          else{
               return 1;
          }
    }
    elsif($type==3){return 1}
    return 0;
}

1;