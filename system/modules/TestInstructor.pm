
package TestInstructor;
use warnings; use strict; 
use Syntax::Keyword::Try;

sub new {my ($class, $args) = @_; 
    bless $args, $class;
}
sub instruct { my ($self,$parser,$instruction, $body) = @_;
print "$body";
}

1;
