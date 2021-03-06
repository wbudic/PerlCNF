# PerlCNF

Perl based Configuration Network File Format Parser and Specifications.
CNF file format supports used format extraction from any text file.
Useful for templates and providing initial properties and values for an application settings.
Has own textual data format. Therefore can also be useful for database data batch processing.

This version doesn't parse the actual __DATA__ section of an perl file yet. Contact me if this is needed, and for any other possible, useful requests.
It is at current v.2.2 specification implemented.

### [You can find the specification here](./CNF_Specs.md).
---
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
 my $cnf2 = new CNFParser('sample.cnf',{DO_enabled=>1, duplicates_overwrite=0});

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
