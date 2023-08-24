
package TestInstructor;
use warnings; use strict; 
use Syntax::Keyword::Try;

sub new {my ($class, $args) = @_; 
    bless $args, $class;
}
sub instruct { my ($self,$parser,$instruction, $body) = @_;
print "$body";
}
#As PROCESSOR this is the function.
sub process{   my ($self,$parser) = @_;
print "Hello ".ref($parser)." you are now done with:" .$parser->{CNF_CONTENT}."\n";
}

1;
