use warnings; use strict;
use Syntax::Keyword::Try;
#no critic "eval"
use lib "tests";
use lib "local";
use lib "system/modules";

require TestManager;
my $test = TestManager -> new($0);
require CNFParser;
my $cnf;

package CNFDelegator {

    our ($self,$parser,$e,$t,$v);
    our %map = (
        'CONST' => \&CONST_, 'CONSTANT' => \&CONST_,
        'ANON'  => \&ANON_,  'VAR'  => \&ANON_,
        'DATA'  => \&DATA_
    );

    sub new{
        ($self,$parser) = @_;
        bless {},$self;
    }

    sub do {
        ($self, $e,$t,$v) = @_;
        my $ret = $map{$t};
        return $ret->($self);
    }
    sub const {
        shift;$e=shift;
        $v = $self->{shift};
        $v = $parser->{$e} if !$v;
        return $v;
    }

sub CONST_{
    my $self = shift;
    $self->{$e} = $v;
}
sub ANON_{
   $parser->anon()->{$e} = $v;
}

sub DATA_{
    $parser->doInstruction($e,$t,$v)
}

};

try{
    ###
    # Test instance creation.
    #
    die $test->failed() if not $cnf = CNFParser->new(undef,{TESTER=>'on'});
    $test->case("Passed new instance CNFParser.");
    #
    $test-> nextCase();
    #
    my $delegator = CNFDelegator->new($cnf);
    $delegator->do('TEST','CONST','123');
    $delegator->do('TEST','VAR','123');
    $test->evaluate("\$cnf has new variable TEST == 123 ",$cnf->anon('TEST'),'123');

    my $t1 = $delegator->const('TESTER');
    $test->evaluate("\$t1 TESTER == on ",$t1,'on');
    $delegator->do("DATA_TABLE",'DATA',qq(
ID`Entry~
#`check1~
#`check2~
#`check3~
    ));
    #
    $test->done();
    #
}
catch{
   $test -> dumpTermination($@);
   $test -> doneFailed();
}

#
#  TESTING ANY POSSIBLE SUBS ARE FOLLOWING FROM HERE  #
#
