package PerlKeywords;
use strict; use warnings;
use Exporter;
our @ISA = 'Exporter';
our @EXPORT = 'span_to_html';
our @EXPORT_OK = qw(%RESERVED_WORDS %KEYWORDS %FUNCTIONS @REG_EXP &matchForCSS &CAP);

our %RESERVED_WORDS = map +($_, 1), qw{ CONST CONSTANT VARIABLE VAR 
                                        FILE TABLE TREE INDEX 
                                        VIEW SQL MIGRATE DO 
                                        PLUGIN MACRO %LOG INCLUDE INSTRUCTOR };


our  %KEYWORDS = map +($_, 1), qw{
    bless caller continue dbmclose dbmopen die do dump else elsif eval exit 
    for foreach goto if import last local my next no our package redo ref 
    require return sub tie tied unless untie until use wantarray while 
    given when default 
    try catch finally 
    has extends with before after around override augment    
};


 our %FUNCTIONS = map +($_, 1), qw{ 
    abs accept alarm atan2 bind binmode chdir chmod chomp chop chown chr 
    chroot close closedir connect cos crypt defined delete each endgrent 
    endhostent endnetent endprotoent endpwent endservent eof exec exists 
    exp fcntl fileno flock fork format formline getc getgrent getgrgid 
    getgrnam gethostbyaddr gethostbyname gethostent getlogin getnetbyaddr 
    getnetbyname getnetent getpeername getpgrp getppid getpriority 
    getprotobyname getprotobynumber getprotoent getpwent getpwnam getpwuid 
    getservbyname getservbyport getservent getsockname getsockopt glob 
    gmtime grep hex index int ioctl join keys kill lc lcfirst length link 
    listen localtime lock log lstat map mkdir msgctl msgget msgrcv msgsnd 
    oct open opendir ord pack pipe pop pos print printf prototype push 
    quotemeta rand read readdir readline readlink readpipe recv rename 
    reset reverse rewinddir rindex rmdir scalar seek seekdir select semctl 
    semget semop send setgrent sethostent setnetent setpgrp setpriority 
    setprotoent setpwent setservent setsockopt shift shmctl shmget shmread 
    shmwrite shutdown sin sleep socket socketpair sort splice split sprintf 
    sqrt srand stat study substr symlink syscall sysopen sysread sysseek 
    system syswrite tell telldir time times tr truncate uc ucfirst umask 
    undef unlink unpack unshift utime values vec wait waitpid warn write 
    say
};



our @REG_EXP = (
      {
        regex=> qr/(['"])(.*)(['"])/,
        css=> 'string'
      },
      {
        regex => qr/(\s*#.*)$/o,
        css   => 'comments'
      }
);

our @LAST_CAPTURED;
sub CAP{
    return \@LAST_CAPTURED;
}

###
# Match regular expression to appropriate style sheet class name.
# @deprecated This will not be employed as we are only interested from this package in from perl to HTML.
###
sub matchForCSS {
    my $string = shift;
    if($string){
        foreach(@REG_EXP){
            my $current   = $_;
            if($string =~ $current -> {regex}){
               @LAST_CAPTURED = @{^CAPTURE};
               return  $current -> {css}
            }
        }
    }
    return;
}
###
# Translate any code script int HTML colored version for output to the silly browser.
###
sub span_to_html {    my ($script,$css, $code_tag_contain) = @_; if($css){$css.=" "}else{$css=""} # $css if specified we need to give it some space in its short life.
    my $out;
    my $SPC  = "&nbsp;";
    my $SPAN = qq(<span class="$css);
    foreach my $line(split /\n/, $script){
        while($line =~ /(\s+)|(\$\w+)|(['"])|(\w+)|(\W+)/gm){

            my @tkns =  @{^CAPTURE}; 
            if    ($1) {                        $out .= $SPC x length($1)
            }elsif($2) {                        $out .= $SPAN.qq(V">$tkns[1]</span>)
            }elsif($3) {                        $out .= $SPAN.qq(Q">$tkns[2]</span>)
            }elsif($4) {
              if    (exists $KEYWORDS{$4}){         $out .= $SPAN.qq(K">$tkns[3]</span>)
              }elsif(exists $FUNCTIONS{$4}){        $out .= $SPAN.qq(F">$tkns[3]</span>)
              }else{                                $out .= $SPAN.qq($tkns[3]</span>) 
              }
            }elsif($5){                         $out .= $SPAN.qq(O">$tkns[4]</span>)
            }
        }   
        $out .= "<br>\n";
    }
    if($code_tag_contain){
       if($code_tag_contain == 1) {
            $out = "<code>\n".$out."\n</code>"
       }else{
            $out = "<$code_tag_contain>\n".$out."\n</$code_tag_contain>"
       }
    }
return \$out;    
}



1;