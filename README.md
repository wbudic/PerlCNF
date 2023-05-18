# PerlCNF

Perl based Configuration Network File Format Parser and Specifications.
CNF file format supports used format extraction from any text file.
Useful for templates and providing initial properties and values for various application settings.
Has own textual data tag format. Therefore can also be useful for database data batch processing.

This project also contains custom build TestManager module for general and all test driven development.

It is at current v.2.8, and specification implemented.

### [You can find the specification here](./Specifications_For_CNF_ReadMe.md).

---

## Status

(2024-5-13) - v.2.8, has new instructions VARIABLE, to stream line under one tag like CONST, but for anons.
Has better tag mauling algorithm. PLUGIN code has been improved, particularly the synchronizing and the linking of properties.

(2022-11-18) - PerlCNF now provides custom test manager and test cases. 
That will in future be used for all projects as an copy from this project.
This is all available in the ./test directory and is not a Perl module.

---

## Installation Of This Perl GitHub Project

* Installation is standard.

```sh
    mkdir ~/dev; cd ~/dev
    git clone https://github.com/wbudic/PerlCNF.git
    cd PerlCNF
```

* To install required modules locally to home, do not run following with sudo in front.
    * cd ~/dev/PerlCNF; #Perl tests and project directory is required to be the starting location.
```sh
    ./install_cpan_modules_required.pl    
```


## Usage

* Copy the system/modules/CNFParser.pm module into your project.
* From your project you can modify and adopt, access it.
* You can also make an perl bash script. 

```perl
use lib "system/modules";
use lib $ENV{'PWD'}.'/htdocs/cgi-bin/system/modules';
require CNFParser;

 my $cnf1 = new CNFParser('sample.cnf');
 #Load config with enabled evaluation on the fly, of perl code embedded in config file.
 my $cnf2 = new CNFParser('sample.cnf',{DO_ENABLED=>1, duplicates_overwrite=0});

 ```
## Sample CNF File

```CNF
<<<CONST
$APP_NAME       = "Test Application"
$APP_VERSION    = v.1.0
>>>
<<$APP_DESCRIPTION<CONST>
This application presents just
a nice multi-line template.
>>

<<@<@LIST_OF_COUNTRIES>
Australia, USA, "Great Britain", 'Ireland', "Germany", Austria
Spain,     Serbia
Russia
Thailand, Greece
>>>

Note this text here, is like an comment, not affecting and simply ignored.
<p>Other tags like this paragraph better put into a CNF property to be captured.</p>

```

```perl

my $cnf = new CNFParser('sample.cnf');
my @LIST_OF_COUNTRIES = @{$cnf -> collection('@LIST_OF_COUNTRIES')};
print "[".join(',', sort @LIST_OF_COUNTRIES )."]";
#prints -> [Australia,Austria,Germany,Great Britain,Greece,Ireland,Russia,Serbia,Spain,Thailand,USA]
print "App Name: ".$cnf->constant('$APP_NAME')."]";
#prints -> App Name: Test Application

```

## Run Test Cases

* Tests are located in the projects **./tests** directory.
* Run individually or all at once with, (the __testAll.pl__ script will automatically select the test files and run them for you):

    ```sh
        perl ./tests/testAll.pl
    ```

* Check also the latest Perl CNF [example.cnf](./tests/example.cnf) scripted also as an tutorial.
  * Yes! That is an actual valid configuration file.
  * To only just run it or check use ``` perl ./tests/testExample.pl  ```
