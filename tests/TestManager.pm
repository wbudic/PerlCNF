#!/usr/bin/env perl
package TestManager;
use warnings; use strict;
use Term::ANSIColor qw(:constants);

###
#  Notice All test are to be run from the project directory.
#  Not in the test directory.
###
sub new {
     my ($class, $test_file, $self) = @_; 
     $test_file = $0 if not $test_file;
     $self = bless {test_file=> $test_file,test_cnt=>1}, $class;
     print  BLUE."Running -> ".WHITE."$test_file\n".RESET;
     return $self;
}

sub failed {
    my ($self, $err) = @_; 
    $err="" if !$err;
    return BLINK. BRIGHT_RED. " on test: ".$self->{test_cnt}." -> $err". RESET
}

sub case { 
    my ($self, $out) =@_;
    print BRIGHT_CYAN,"\tCase ".$self->{test_cnt}.": $out\n".RESET
}
sub subcase {
    my ($self, $out) =@_;
    my $sub_cnt = ++$self->{sub_cnt};
    print GREEN."\t   Case ".$self->{test_cnt}.".$sub_cnt: $out\n".RESET
}

sub nextCase {
    my ($self) =@_;
    $self->{test_cnt}++;
    $self->{sub_cnt}=0
}

sub done {
    my ($self) =@_;
    print BOLD "Test cases ($self->{test_cnt}) have ", BRIGHT_GREEN ,"PASSED",RESET," for test file:", RESET WHITE, " .$self->{test_file}\n", RESET;
    print $self->{test_cnt}."|SUCCESS|".$self->{test_file},"\n"    
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
    if(ref($comment) =~ /Exception/){
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
        $message = $comment->{'message'}.$trace;
        $comment = $message;
        #Old die methods could be present, caught by an Exception, manually having Error@{lno.} set.
        if($message =~ /^Error\@(\d+)/){ 
           $ErrAt = "\\\@$1";
        }
    }else{
     ($file,$lnErr) = ($comment =~ m/.*\s*at\s*(.*)\sline\s*(\d*)\.$/); 
    }
    
    
    open (my $flh, '<:perlio', $file) or die("Error $! opening file: $file");
          my @slurp = <$flh>;
    close $flh;
    print BOLD BRIGHT_RED "Test file failed -> $comment";
    our $DEC = "%0".(length($slurp[-1]) + 1)."d   ";
    my $clnt=int(0);
    for(my $i=0; $i<@slurp;$i++)  { 
        local $. = $i + 1;
        my $line = $slurp[$i]; 
        if($. >= $lnErr+1){                  
           print $comment, RESET.frmln($.).$line;
           print "[".$file."]\n\t".BRIGHT_RED."Failed\@Line".WHITE." $i -> ", $slurp[$i-1].RESET;
           last  
        }elsif($line=~m/^\s*(\#.*)/){
            if( $1 eq '#'){
                $comment .= "\n".RESET.frmln($.).ITALIC.YELLOW.'#' ;
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
        }
        
        if(++$clnt>50 && $. < $lnErr-50){
             $clnt = $past = $cterminated = 0;
             $comment ="" # trim excessive pre line collecting.
        }
    }
}

our $DEC =  "%-2d %s"; #under 100 lines pad like -> printf "%2d %s", $.
sub frmln { my($at)=@_;
       return sprintf($DEC,$at)
}