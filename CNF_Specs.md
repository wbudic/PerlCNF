# Configuration Network File Format Specifications


## Introduction

This is a simple and fast file format. That allows setting up of network and database applications with initial configuration values.
These are usually standard, property name and value pairs. Containing possible also SQL database structures statements with basic data.
It is designed to accommodate a parser to read and provide for CNF property tags. 

These can be of four types, using all a textual similar presentation.
In general are recognized as constants, anons, collections or lists, that re either arrays or hashes.

Operating system environmental settings or variables are considered only as the last resort to provide for a property value.
As these can hide and hold the unexpected value for a setting.

With the CNF type of an application configuration system. Global settings can also be individual scripted with an meaningful description.
Which is pretty much welcomed and encouraged. As the number of them can be quite large, and meanings and requirements, scattered around code comments or various documentation. Why not keep this information next to; where you also can set it.

CNF type tags are script based, parsed tags of text, everything else is ignored. DOM based parsed tags, require definitions and are hierarchy specific, path based. Even comments, have specified format. A complete different thing. However, in a CNF file you, can nest and tag, DOM based scripts. But not the other way. DOM based scripts are like HTML, XML. They might scream errors if you place in them CNF stuff.

## General CNF Formatting Rules

1. Text that isn't CNF tagged is ignored in the file and can be used as comments.
2. CNF tag begins with an **<<** or **<<<** and ends with an **>>>** or **>>**.
3. If instruction is contained the tag begins with **<<** and ends with a **>>**.
4. Multi line values are tag ended on a separate line with an **>>>**.
5. CNF tag value can post processed by placing macros making it a template.
6. Standard markup of a macro is to enclose the property name or number with a triple dollar signifier **\$\$\$**{macro}**\$\$\$**.
    1. Precedence of resolving the property name/value is by first passed macros, then config anons and finally the looking up constance's.
    2. Nested macros resolving from linked in other properties is currently not supported.
7. CNF full tag syntax format: **```<<{$|@|%}NAME{<INSTRUCTION>}{<any type of value>}>>```**, the name and instruction parts, sure open but don't have to be closed with **>** on a multiple line value.
8. CNF instructions and constants are uppercase.
    1. Example 1 format with instruction: ```<<<CONST\n{name=value\n..}\n>>>``` autonomous const, with inner properties.
    2. Example 2 format with instruction: ```<<{$sig}{NAME}<CONST {multi line value}>>>``` A single const property with a multi line value.
    3. Example 3 format with instruction: ```<<CONST<{$sig}{NAME}\n {multi line value}>>>``` A single const property with a multi line value.
    4. Example 4 format with instruction: ```<<{NAME}<{INSTRUCTION}<{value}>>>``` A anon.
    5. Example 5 format with instruction: ```<<{$sig}{NAME}<{INSTRUCTION}\n{value}\n>>>```.
9.  CNF instructions are all uppercase and unique, to the processor.
10. A CNF constant in its property name is prefixed with an '**$**' signifier.
11. Constants are usually scripted at the beginning of the file, or parsed first in a separate file.
12. The instruction processor can use them if signifier $ surrounds the constant name. Therefore, replacing it with the constants value if further found in the file.

    ```HTML
     <<<CONST $APP_PATH=~/MyApplication>>>
     <<app_path<$APP_PATH$/module/main>>>
    ```

13. Property names, Constant, Anon refer to the programmatically assigned variable name.
14. *CNF Constant* values are store specific.
15. Constants can't be changed for the life of the application or service issued.
16. Storage of CNF constants declared can be preceded to the file based one.
17. A Constant CNF value is not synchronized, unlike an anon from script to storage configuration. It has to be created from the scripted if missing in storage.
18. i.e. If stored in a database or on a network node. After the file declaration fact.
19. Missing file based storage settings can be next queried from the environmental one.
    1. This is to be avoided if possible.
20. File storage encountered constants override system environmental ones.
    1. i.e. System administrator has set them.
21. Database storage encountered constants override file set ones.
    1. i.e. User of application has set them.
22. CNF Constant values can be changed in the script file.
    1. If not present in script file, then an application setting must proceed with its default.
    2. CNF Constants can be declared only once during initial parsing of script files.
    3. Rule of thumb is that Constants are synchronized with an applications release version.
    4. Static constants, are script or code only assigned values.
    5. CNF Anons can override in contrast previously assigned value.
23. A CNF Anon is similar to constants but a more simpler property and value only pair.
    1. Anons are so called because they are unknown or unexpected by the configuration framework, store to object intermediate.
    2. Constants that turn up in the anon list, are a good indicator that they are not handled from script. Forgotten become anons.
    3. Anons similar to constants, once in the database, overtake the scripted or application default settings value.
    4. Static anons, are those that are set in the database, and/or are not merged with application defaults.
    5. Anons hashed are programmatically accessed separately to constants.
       1. It is fine to have several different applications, to share same storage, even if they have different implementation.
       2. Constants will be specific to application, while anons can change in different purpose script files.
24. *Anon* is not instruction processed. Hence anonymous in nature for its value. Applications using this CNF system usually process and handles this type of entries.
25. Anon has no signifier, and doesn't need to have an application default.
26. Anon value is in best practice and in general synchronized, from script to a database configuration store. It is up to the implementation.
27. Anon value is global to the application and its value can be modified.

    ```HTML
            <<USE_SWITCH<true>>>
            <<DIALOG_TITLE_EN<MyApplication Title>>>
    ```

    1. Anon value can be scripted to contain template like but numbered parameters.
    2. When querying for an anon value, replacement parameter array can be passed.
    3. Numbering is from **\$\$\$1\$\$\$**..**$$$(n...)\$\$\$** to be part of its value. Strategically placed.

    ```HTML
        <<GET_SUB_URL<https://www.$$$1$$$.acme.com/$$$2$$$>>>
    ```

    ```PERL
       # Perl language
       my $url = $cnf->anon('GET_SUB_URL',('tech','main.cgi'));
       # $url now should be: https://www.tech.acme.com/main.cgi
       eval ($url =~ m/https:\.*/)
             or warn "Failed to obtain expected URL when querying anon -> GET_SUB_URL"
    ```

28. Listing is an reappearing same name tag postfixed with an **\$\$**.

    ```HTML Example 1:
                <<INS$$>ls -la>
                <<INS$$>uname -a>
    ```

29. Listing is usually a named list of instructions, items grouped and available as individual entries of the listing value.

    ```HTML Example 2:
                <<Animals$$>Cat>
                <<Animals$$>Dog>
                <<Animals$$>Eagle>
    ```

## CNF Tag Formats

### Property Value Tag

   ```HTML
        <<{name}<{value}>>>
   ```

### Instruction Value Tag

   ```HTML
        <<<{INSTRUCTION}
        {value\n...valuen\n}>>>
   ```

   ```HTML
        <<{name}<{INSTRUCTION}
        {value\n...valuen\n}>>>
   ```

### Full Tag

```javascript
    <<{$sig}{name}<{INSTRUCTION}
        {value\n...value\n}
    >>>
```

**Examples:**

```HTML
        <<$HELP<CONST
            Sorry help is currently.
            Not available.
        >>
        <<<CONST
            $RELEASE_VER = 1.8
            $SYS_1 =    10
            $SYS_2 = 20
            $SYS_3 =      "   Some Nice Text!   "
        >>
       <<PRINT_TO_HELP<true>>
```

## CNF Collections Formatting

1. CNF collections are named two list types.
   1. Arrays
   2. Hashtables
2. Collection format.
   1. {T} stands for type signifier. Which can only be either ''@'' for array type, or ''%'' for hash.
   2. NAME is the name of the collection, required. Later this is searched for with signifier prefixed.
   3. DATA is delimited list of items.
      1. For hashes named as property value pairs and assigned with '=', for value.
         1. Hash entries are delimited by a new line.
      2. For arrays, values are delimited by new line or an comma.
      3. White space is preserved if values are quoted, otherwise are trimmed.

   ```TEXT
    Format:    <<@<{T}NAME>DATA>>>

    Examples:
    # Following provides an array of listed animal types.
    <<@<@animals<Cat,"Dog","Pigeon",Horse>>>
    # Following provides an array with numbers from 0..8
    <<@<@numbers<1,2,3,4,5
    6
    7
    8
    >>>

    # Following is hashing properties. Notice the important % signifier for the hash name as %settings.
    <<@<%settings<
        AppName = "UDP Server"
        port    = 3820
        buffer_size = 1024
        pool_capacity = 1000    
    >>
   ```

## Instructions & Reserved words

   1. Reserved words relate to instructions, that are specially treated, and interpreted by the parse to perform extra or specifically processing on the current value.
   2. Current Reservet words list is.
       1. CONST
       2. DATA
       3. FILE
       4. TABLE
       5. INDEX
       6. VIEW
       7. SQL
       8. MIGRATE
       9. MACRO
          1. Value is searched and replaced by an property value, outside the property scripted.
          2. Parsing abruptly stops if this abstract property specified is not found.
          3. Macro format specifications, have been aforementioned in this document. However make sure that you macro an constant also including the *$* signifier if desired.


## Database and SQL Instruction Formatting

(Note - this documentation section not complete, as of 2020-02-14)

### About

CNF supports basic SQL Database structure statement generation. This is done via instruction based CNF tags. Named **sqlites**.

1. Supported is table, view, index and data creation statements.
2. Database statements are generic text, that is not further processed.
3. There is limited database interaction, handling or processing to be provided.
   1. Mainly for storage transfer of CNF constants, from file to database.
   2. File changes precede database storage only in newly assigned constants.
4. Database generated is expected to have a system  SYS_CNF_CONFIG table, containing the constants unique name value pairs, with optional description for each.
   1. This is a reserved table and name.
   2. This table must contain a **$RELEASE_VER** constants record at least.

### SQLite Formatting

* SQLites have the following reserved instructions:

1. TABLE

    ```HTML
        <<MyAliasTable<TABLE
                    ID INT PRIMARY KEY NOT NULL,
                    ALIAS VCHAR(16) UNIQUE CONSTRAINT,
                    EMAIL VCHAR(28),
                    FULL_NAME VCHAR(128)
        >>>
    ```

2. INDEX

    ```HTML
        <<MyAliasTable<INDEX<idx_alias on MyAliasTable (ALIAS);>>>
    ```

3. SQL
     1. SQL statements are actual full SQL placed in the tag body value.

    ```HTML
        <<VW_ALIASES>SQL
            CREATE VIEW VW_ALIASES AS SELECT ID,ALIAS ORDER BY ALIAS;
        >>>
    ```

4. DATA
    1. Data is specifically parsed, not requiring quoted strings and isn't delimited by new lines alone.
    2. Data rows are ended with the **"~"** delimiter. In the tag body.
    3. Data columns are delimited with the invert quote **"`"** (back tick) making the row.
    4. First column is taken as the unique and record identity column (UID).
    5. Data is to be updated in storage if any column other than the UID, has its contents changed in the file.
       1. This behavior can be controlled by disabling something like  an auto file storage update. i.e. during application upgrades. To prevent user set settings to reset to factory defaults.
       2. The result would then be that database already stored data remains, and only new ones are added. This exercise is out of scope of this specification.

    ```HTML
        <<MyAliasTable<DATA
        01`admin`admin@inc.com`Super User~
        02`chef`chef@inc.com`Bruno Allinoise~
        03`juicy`sfox@inc.com`Samantha Fox~
        >>
    ```

5. FILE
   1. Expects a file name assigned value, file containing actual further CNF DATA rows instructions, separately.
   2. The file is expected to be located next to the config file.
   3. File is to be sequentially buffer read and processed instead as a whole in one go.
   4. The same principles apply in the file as to the DATA instruction CNF tag format, that is expected to be contained in it.

    ```HTML
        <<MyItemsTbl<FILE data_my_app.cnf>
    ```

6. MIGRATE
   1. Migration are brute sql statements to be run based on currently installed previous version of the SQL database.
   2. Migration is to be run from version upwards as stated and in the previous database encountered.
      1. i.e. If encountered old v.1.5, it will be upgraded to v.1.6 first, then v.1.7...
   3. Migration is not run on newly created databases. These create the expected latest data structure.
   4. SQL Statements a separated by ';' terminator. To be executed one by one.

    ```HTML
        <<1.6<MIGRATE
                ALTER TABLE LOG ADD STICKY BOOL DEFAULT 0;
        >>
        <<1.8<MIGRATE
            CREATE TABLE notes_temp_table (LID INTEGER PRIMARY KEY NOT NULL, DOC TEXT);
            INSERT INTO notes_temp_table SELECT `LID`,`DOC` FROM `NOTES`;
            DROP TABLE `NOTES`;
            ALTER TABLE `notes_temp_table` RENAME TO `NOTES`;
        >>
    ```

## Sample Perl Language Usage

7. *DO*
   1. CNF DO instruction is *experimental*, purely perl programming language related.
   2. It provides perl code evaluation during parsing giving also access to parser and its variables as do's there sequentially appear.
   3. It is recommended to comment out this feature, if never is to be used or found not safe to have such thing enabled.
   4. These if named are assigned as anons, with the last processed value as the return. Making them evaluated and processed ever only once.

```perl
<<<DO
print "Hello form CNF, you have ".(scalar %anons) ." anons so far.\n"
>>>
```

**~/my_application.pl** file contents:

```PERL

use lib "system/modules";
use lib $ENV{'PWD'}.'/perl_dev/WB_CNF/system/modules';
require CNFParser;
require Settings;

my @expected = ("$MY_APP_LIB_RELATIVE", "$MY_APP_DB_RELATIVE");
my $path = $ENV{'PWD'}."/perl_dev/WB_CNF/db/configuration.cnf";
# Loading twice config here with object constructor with and without path.
# To show dual purpose use.
my $cnf1  = CNFParser->new($path);
# Nothing parsed yet construct.
my $cnf2  = CNFParser->new();
   # We relay that the OS environment has been set for CNF constant settings if missing
   # in the configuration file. Adding after parse has no effect if found in file.
   $cnf2 -> addENVList(@expected);
   # Parse finally now. Parse can be called on multiple different files, if desired.
   $cnf2 -> parse($path);
my $LIB_PATH;

print "List of constants in file: $path\n";
foreach my $prp ($cnf->constants()){
    print "$prp=", $cnf->constant($prp),"\n";
}
if(!$cnf->constant('$MY_APP_LIB_RELATIVE')){
    warn 'Missing $MY_APP_LIB_RELATIVE setting.';
    $LIB_PATH = $cnf2->constant('$MY_APP_LIB_RELATIVE');
    die  'Unable to get required $MY_APP_LIB_RELATIVE setting!' if(not $LIB_PATH)
}

print "Welcome to ", $cnf->constant('$APP_NAME'), " version ", $cnf->constant('$RELEASE_VER'), ".\n";
```

**~//perl_dev/WB_CNF/db/configuration.cnf** file contents:

```HTML

# List command anon with the name of 'list'.
<<list>ls -lh dev|sort>
<<<CONST
$RELEASE_VER = 1.0
$APP_NAME="My Application Sample"
>>>

```

***

   Document is from project ->  <https://github.com/wbudic/LifeLog/>

   An open source application.

<center>Sun Stage - v.2.2 2021</center>
