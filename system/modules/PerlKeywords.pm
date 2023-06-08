package PerlKeywords;
use strict; use warnings;
use Exporter;
our @ISA = 'Exporter';
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


1;