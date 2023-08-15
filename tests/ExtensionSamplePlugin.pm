package ExtensionSamplePlugin;

use strict;
use warnings;
use feature qw(signatures);
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

sub process ($self, $parser, $property) {
    my @list = $parser->list($property);
    for my $id (0 .. $#list){ 
        my $entry = $list[$id];
        my $type  = ref($entry);
        if($type eq 'InstructedDataItem'){
           $parser->data()->{$entry->{ele}.'.'.$entry->{aid}} = doInstruction($parser, $entry)
        }
    }
    return $property;
}

sub doInstruction($parser,$struct){
    if($struct->{ins} eq 'RANGE'){
        $struct->{val} =~ /(\d+)\.\.(\d+):(.*)/;
        my @data = ($1..$2); my @formula = ($3=~/./g);
        foreach (@data) {
            my $n = $_;
            my ($l,$r,$opr,$res)=(int 0, int 0, undef,0);
            foreach(@formula) {
                if($_ eq'n'){
                  if(!$l){$l = $n}else{$r = $n}
                }elsif($_ eq '+'){
                    $opr = 1;
                }elsif($_ eq '-'){
                    $opr = 2;
                }elsif($_ eq '*'){
                    $opr = 3;
                }elsif($_ eq '/'){
                    $opr = 4;
                }else{
                  if(!$l){$l = $_}else{$r = $_} 
                }
                if($r && $opr){
                    $res += operate($opr,$l,$r)
                }
            }
             $data[$n-1] = $res
        }
        return \@data;
    }
}

sub operate($opr, $l,$r){
    if($opr == 1){ 
        return $l + $r;
    }
    elsif($opr == 2){ 
        return $l - $r;
    }
    elsif($opr == 3){ 
        return $l * $r;
    }
    elsif($opr == 4){ 
        return $l / $r;
    }
}

1;