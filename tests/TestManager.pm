#!/usr/bin/env perl
##
# Test Manager of specific for sophisticated test driven programming
# of project based local libraries in Perl.
# Nothing quite other than it, yet does exists.
##
package TestManager;
use warnings; use strict;
use Term::ANSIColor qw(:constants);
use Timer::Simple;

my $timer = Timer::Simple->new(start => 0, string => 'human');
my $stab  = "";

###
#  Notice All test are to be run from the project directory.
#  Not in the test directory.
###
sub new {
     my ($class, $test_file, $self) = @_;
     $test_file = $0 if not $test_file;
     $self = bless {test_file=> $test_file,test_cnt=>1,sub_cnt=>0,sub_err=>0}, $class;
     print  BLUE."Running -> ".WHITE."$test_file\n".RESET;
     $self->{open}=0;
     return $self;
}

sub failed {
    my ($self, $err) = @_;
    $err="" if !$err;
    my $sub_cnt = ++$self->{sub_cnt};
    ++$self->{sub_err};
    my ($package, $filename, $line) = caller; $filename =~ s/^(\/(.+)\/)//gs;
    print BLINK. BRIGHT_RED. "\t$stab   Fail ".$self->{test_cnt}.".".$sub_cnt.": $err",
                         BLUE, qq(\n\t$stab\t at -> ./$filename line on $line.\n), RESET;
    return $self
}

sub passed {
    my ($self, $msg) = @_;
    $msg ="" if !$msg;
    my $sub_cnt = ++$self->{sub_cnt};
    my ($package, $filename, $line) = caller; $filename =~ s/^(\/(.+)\/)//gs;
    print BRIGHT_GREEN, "\t$stab   Pass ".$self->{test_cnt}.".".$sub_cnt.": $msg",
                  BLUE, qq( at -> ./$filename line on $line.\n), RESET;
    return $self
}

sub case {
    my ($self, $out) =@_;
    my ($package, $filename, $line) = caller; $filename =~ s/^(\/(.+)\/)//gs;
    $stab="";
    nextCase($self) if $self->{open};
    print BRIGHT_CYAN,"\tCase ".$self->{test_cnt}.": $out",
          BLUE, qq(\n\t\t at -> ./$filename line on $line.\n), RESET;
    $self->{open}=1;
    return $self
}

sub subcase {
    my ($self, $out) =@_;
    my $sub_cnt = ++$self->{sub_cnt};
    print GREEN,"\t$stab   Sub->".$self->{test_cnt}.".$sub_cnt: $out\n", RESET;
    $stab ="     ";
    return $self;
}

sub nextCase {
    my ($self) =@_;
    if($self->{sub_err} > 0){
        my $errors = "errors";  $errors = "error" if $self->{sub_err} == 1;
        print "\tCase ".$self->{test_cnt}.BRIGHT_RED." failed with ".$self->{sub_err} ." $errors!\n".RESET;
        $self->{case_err} += $self->{sub_err};
        $self->{sub_err} = 0;
    }
    $self->{test_cnt}++;
    $self->{sub_cnt}=0;
    $self->{open}=0
}
###
# Optionally measure time a case needed.
###
sub start {
    my $self = shift;
    $timer->start();
    print BRIGHT_CYAN,"\tStarted Timer: ".$timer->hms('%01d h %01d m %02.2f s')."\n";
}
sub stop {
    my $self = shift;
    $timer->stop();
    print BRIGHT_CYAN,"\tStopped Timer: ".$timer->hms('%01d h %01d m %02.2f s')."\n";
}
###
# Performs non critical evaluation test.
# As test cases file manages to die on critical errors
# or if test file should have an complete failed run and bail out, for immidiate attention.
#
# @return 1 on evaluation passed, 0 on failed.
# NOTICE -> Pass scallars to evaluate or array parameters will autoexpand.
###
sub evaluate {
    my ($self, $aa, $bb, $cc)=@_;
    if(!$cc && defined($cc)){
        $cc = ref(\$cc);
    }
    if ($aa&&$bb&&$cc) {
        my $swp = $aa; $aa = $bb; $bb = $cc; $cc = $swp}
    else{
        $cc="test-is-undef"
    }
    if (@_== 2 && $aa || $aa && !$bb && $cc eq 'test-is-undef'){
        print GREEN."\t$stab   Test ".$self->{test_cnt} .'.'. ++$self->{sub_cnt}.": Passed -> a-> [$aa] object is defined!\n"
    }elsif(defined $aa && $aa eq $bb){
        print GREEN."\t$stab   Test ".$self->{test_cnt} .'.'. ++$self->{sub_cnt}.": Passed $cc a-> [$aa] equals b-> [$bb]\n"
    }else{
        ++$self->{sub_err};
        if(@_== 3 && $cc eq 'test-is-undef'){
            my $swp = $aa; $aa = $bb; $bb = $cc; $cc = $swp
        }
        my ($package, $filename, $line) = caller; $filename =~ s/^(\.\/.*\/)/\@/;
        print BLINK. BRIGHT_RED."\t$stab   Test ".$self->{test_cnt} .'.'. ++$self->{sub_cnt}.
              ": Failed! (". $self->{sub_err} .")",RESET, YELLOW, " $filename line $line\n",
               BRIGHT_RED,"[$cc].eval(->  \$a->$aa, \$b->$bb  <-)\n",RESET;
        return 0;
    }
    return 1;
}

###
# Performs non critical evaluation if an scalar has a defined value.
# Attributes are $var for variable name and, $val the actual variable.
# @return 1 on evaluation passed, 0 on failed.
###
sub isDefined{
    my ($self, $var, $val)=@_;
    die "The var parameter is missing for val for TestManager->isDefined($var,$val)!" if not defined $val;
    my $ref = ref($val);
    if (defined $val||$ref){
        print GREEN."\t$stab   YDef ".$self->{test_cnt} .'.'. ++$self->{sub_cnt}.": Passed -> Scalar [$var] is defined.\n"
    }else{
        ++$self->{sub_err};
        print BLINK. BRIGHT_RED."\t$stab   YDef ".$self->{test_cnt} .'.'. ++$self->{sub_cnt}. ": Failed!"." ($self->{sub_err}) ".RESET. RED."Scalar [$var] is not defined!\n";
        return 0;
    }
    return 1;
}

sub isZeroOrEqual{
    my ($self, $var, $aa, $bb)=@_;
    if ($aa == 0 or $aa==$bb){
        print GREEN."\t$stab   YDef ".$self->{test_cnt} .'.'. ++$self->{sub_cnt}.": Passed -> Scalar [$var] is ZeroOrEqual.\n"
    }else{
        ++$self->{sub_err};
        print BLINK. BRIGHT_RED."\t$stab   YDef ".$self->{test_cnt} .'.'. ++$self->{sub_cnt}. ": Failed!"." ($self->{sub_err}) ".RESET. RED."Scalar [$var] is not defined!\n";
        return 0;
    }
    return 1;
}

###
# Performs non critical evaluation if an scalar is undefined.
# Atributes are $var for variable name and, $val the actual variable.
# @return 1 on evaluation passed, 0 on failed.
###
sub isNotDefined{
    my ($self, $var, $val)=@_;
    if (not defined $val){
        print GREEN."\t$stab   NDef ".$self->{test_cnt} .'.'. ++$self->{sub_cnt}.": Passed -> Scalar [$var] is not defined.\n"
    }else{
        ++$self->{sub_err};
        print BLINK. BRIGHT_RED."\t$stab   NDef ".$self->{test_cnt} .'.'. ++$self->{sub_cnt}. ": Failed!"." ($self->{sub_err}) ".RESET. RED."Scalar [$var] is defined!\n";
        return 0;
    }
    return 1;
}

sub done {
    my ($self) =@_;
    my $result =  BOLD."Test cases ($self->{test_cnt}) have ";
    if(defined($self->{sub_err}) && $self->{sub_err} > 0){
        $self->{case_err} += $self->{sub_err};
    }
    if(defined($self->{case_err}) && $self->{case_err} > 0){
      my $errors = "errors";  $errors = "error" if $self->{case_err} == 1;
      $result .= $self->{case_err} . BRIGHT_RED . " evaluation $errors.".RESET.BOLD." Status is ";
      print $result, BRIGHT_RED."FAILED".RESET." for test file:". RESET WHITE.$self->{test_file}."\n". RESET;
      print $self->{test_cnt}."|FAILED|".$self->{test_file},"\n"
    }else{
      print $result, BRIGHT_GREEN."PASSED".RESET." for test file: ". RESET WHITE.$self->{test_file}."\n". RESET;
      print $self->{test_cnt}."|SUCCESS|".$self->{test_file},"\n"
    }
}
sub doneFailed {
    my ($self) =@_;
    print $self->{test_cnt}."|FAILED|".$self->{test_file},"\n"
}

###
# Following routine is custom made by Will Budic.
# The pattern it seeks is like this comment in source file.
# To display code where error occured.
###
sub dumpTermination {
    my ($failed, $comment, $past, $message, $ErrAt, $cterminated) = @_;
      my ($file,$lnErr, $trace);
      my $refT = ref($comment);
    if($refT eq 'Specio::Exception'){
         my $trace = "";
         my $i = 3;
         foreach my $st($comment->stack_trace()->frames()){
            if($trace){
                $trace .= ' 'x$i .RED.$st->as_string()."\n";
                $i+=3;
            }else{
                $trace = RED.$st->as_string()."\n";
                $trace =~ s/called at/\n   thrown from \-\>/gs;
                #($file,$lnErr) =($st->filename(),$st->line())
            }
        }
           $comment = $message = $comment->{'message'}.$trace;
        $comment =~ s/eval \{.+\} at/cought at/gs;
        #Old die methods could be present, caught by an Exception, manually having Error@{lno.} set.
        if($message =~ /^Error\@(\d+)/){
           $ErrAt = "\\\@$1";
        }
    }elsif($refT =~ /Exception/){
        my $trace = "";
        my $i = 3;
        foreach my $st($comment->trace()->frames()){
            if($trace){
                $trace .= ' 'x$i .RED.$st->as_string()."\n";
                $i+=3;
            }else{
                $trace = RED.$st->as_string()."\n";
                $trace =~ s/called at/\n   thrown from \-\>/gs;
                ($file,$lnErr) =($st->filename(),$st->line())
            }
        }
        $comment = $message = $comment->{'message'}.$trace;
        $comment =~ s/eval \{.+\} at/cought at/gs;
        #Old die methods could be present, caught by an Exception, manually having Error@{lno.} set.
        if($message =~ /^Error\@(\d+)/){
           $ErrAt = "\\\@$1";
        }else{
            my $error;
            ($error,$file,$lnErr) = ($message =~ m/(.*)\sat\s*(.*)\sline\s(\d*)\./)
        }
    }else{
     ($trace,$file,$lnErr) = ($comment =~ m/(.*)\sat\s*(.*)\sline\s(\d*)\.$/);
    }
    print BOLD BRIGHT_RED "Test file failed -> $comment";
    if($file){
    open (my $flh, '<:perlio', $file) or die("Error $! opening file: '$file'\n$comment");
          my @slurp = <$flh>;
    close $flh;
    our $DEC = "%0".(length(scalar(@slurp)))."d   ";
    my  $clnt=int(0);
    for(my $i=0; $i<@slurp;$i++)  {
        local $. = $i + 1;
        my $line = $slurp[$i];
        if($. >= $lnErr+1){
           print $comment, RESET.frmln($.).$line;
           print "[".$file."]\n\t".BRIGHT_RED."Failed\@Line".WHITE." $i -> ", $slurp[$i-1].RESET;
           last
        }elsif($line=~m/^\s*(\#.*)/){
            if( $1 eq '#'){
                $comment .= "".RESET.frmln($.).ITALIC.YELLOW."#\n" ;
                $past = $cterminated = $clnt= 0
            }
            elsif($past){
                $_=$1."\n"; $comment = "" if $cterminated && $1=~m/^\s*\#\#\#/;
                $comment .= RESET.frmln($.).ITALIC.YELLOW.$_;
                $cterminated = 0;
            }
            else{
                $comment = RESET.frmln($.).ITALIC.YELLOW.$1."\n";
                $past = $cterminated = 1;
            }
        }elsif($past){
            $line= $slurp[$i];
            if($ErrAt && $line =~ /$ErrAt/){
                $comment .= RESET.frmln($.).BOLD.RED.$line;
            }else{
                $comment .= RESET.frmln($.).$line;
            }
        }else{
            if($lnErr == $. || $ErrAt && $line =~ /$ErrAt/){
                $comment .= RESET.frmln($.).BOLD.RED.$line;
            }else{
                $comment .= RESET.frmln($.).$line;
            }
        }

        if(++$clnt>50 && $. < $lnErr-50){
             $clnt = $past = $cterminated = 0;
             $comment ="" # trim excessive pre line collecting.
        }
    }
    }
    exit;
}

our $DEC =  "%-2d %s"; #under 100 lines pad like -> printf "%2d %s", $.
sub frmln { my($at)=@_;
       return sprintf($DEC,$at)
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