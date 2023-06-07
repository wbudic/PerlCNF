# Configuration Network File Format Specifications

## Introduction

This is a simple and fast file format. That allows setting up of network and database applications with initial configuration values.
These are usually standard, property name and value pairs. Containing possible also SQL database structures statements with basic data.
It is designed to accommodate a parser to read and provide for CNF property tags.

These can be of four types, using all a textual similar presentation.
In general are recognized as constants, anons, collections or lists, that are either arrays or hashes.

Operating system environmental settings or variables are considered only as the last resort to provide for a property value.
As these can hide and hold the unexpected value for a setting.

With the CNF type of an application configuration system. Global settings can also be individual scripted with an meaningful description.
Which is pretty much welcomed and encouraged. As the number of them can be quite large, and meanings and requirements, scattered around code comments or various documentation. Why not keep this information next to; where you also can set it.

CNF type tags are script based, parsed tags of text, everything else is ignored. DOM based parsed tags, require definitions and are hierarchy specific, path based. Even comments, have specified format. A complete different thing. However, in a CNF file you, can nest and tag, DOM based scripts. But not the other way. DOM based scripts are like HTML, XML. They might scream errors if you place in them CNF stuff.

Quick Jump: [CNF Tag Formats](#cnf-tag-formats)  |  [CNF Collections Formatting](#cnf-collections-formatting) | [Instructions & Reserved Words](#instructions-and-reserved-words) | [Scripted Data Related Instructions](#scripted-data-related-instructions)

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
9. CNF instructions are all uppercase and unique, to the processor.
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

30. Anon used as an **reserve** format is some applications internal meta property.
    1. These are prefixed with an **^** to the anon property name.
    2. They are not expected or in any specially part of the CNF processing, but have here an special mention.
    3. It is not recommended to use reserve anons as their value settings, that is; can be modified in scripts for their value.
    4. Reserve anon if present is usually a placeholder, lookup setting, that in contrast if not found there, might rise exceptions from the application using CNF.

    ```HTML Example 2:
                Notice to Admin, following please don't modify in any way! 
                Start --> { 
                <<^RELEASE>2.3>>
                <<^REVISION>5>>
                <<META><DATA>^INIT=1`^RUN=1`^STAGES_EXPECTED=5>> } <-- End 
    ```


## CNF Tag Formats

Quick Jump: [Introduction](#introduction)  |  [CNF Collections Formatting](#cnf-collections-formatting) | [Instructions & Reserved Words](#instructions-and-reserved-words) | [Scripted Data Related Instructions](#scripted-data-related-instructions)

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
    <<{$sig}{name}<{INSTRUCTION}>
        {value\n...value\n}
    >>
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

## Mauling Explained

1. Mauling refers to allowing for/or encountering inadequate possible script format of an CNF property.
    1. These still should pass the parsers scrutiny and are not in most cases errors.
    2. There are in general three parts expected for an CNF property.
        1. Tag name.
        2. Instruction.
        3. Value
    3. CNF property value tag turns the instruction the value, if the value is not separated from it.
    4. CNF only instructed, will try to parse the whole value to make multiple property value pairs.
        1. The newline is the separator for each on created.
    5. Ver. 2.8 of PerlCNF is the third third rewrite to boom and make this algorithm efficient.
2. Example. Instruction is mauling value:

    ```perl
        <<CNF_COUNTRY_OF_ORIGIN<Australia>>>
    ```

3. Example. Instruction mauls into multi-new line value:

    ```perl
       <<APP_HELP_TXT<CONST
       This is your applications help text in format of an constance. 
       All you see here can't be dynamically changed.
       You might be able to change it in the script though. 
       And re-run your app.
       >>        
    ```

4. Example. Tag name mauled:

    ```perl
       <<<CONST
       $APP_HELP_TXT='This is your applications help text in format of an constance.'       
       >>        
    ```

5. Example. Instruction mauled or being disabled for now:
    1. This will fire warnings but isn't exactly an error.
    2. Introduced with CNF release v.2.5.

    ```perl
       <<PWD<>path/to/something>>        
    ```


## CNF Collections Formatting
Quick Jump: [Introduction](#introduction)  | [CNF Tag Formats](#cnf-tag-formats)  | [Instructions & Reserved Words](#instructions-and-reserved-words) | [Scripted Data Related Instructions](#scripted-data-related-instructions)

1. CNF collections are named two list types.
   1. Arrays
   2. Hashtables
2. Collection format.
   1. {T} stands for type signifier. Which can only be either ''@'' for array type, or ''%'' for hash.
   2. NAME is the name of the collection, required. Later this is searched for with signifier prefixed.
   3. DATA is delimited list of items.
      1. For hashes named as property value pairs and assigned with '=', for value.
         1. Hash entries are delimited by a new line.
      2. For arrays, values are delimited by new line or a comma.
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

## Instructions And Reserved Words

Quick Jump: [Introduction](#introduction)  | [CNF Tag Formats](#cnf-tag-formats)  | [CNF Collections Formatting](#cnf-collections-formatting) | [Scripted Data Related Instructions](#scripted-data-related-instructions)

   1. Reserved words relate to instructions, that are specially treated, and interpreted by the parser to perform extra or specifically processing on the current value.
   2. Reserved instructions can't be used for future custom ones, and also not recommended tag or property names.
   3. Current Reserved words list is.
       - CONST    - Concentrated list of constances, or individually tagged name and its value.
       - VARIABLE - Concentrated list of anons, or individually tagged name and its value.
       - DATA     - CNF scripted delimited data property, having uniform table data rows.
       - FILE     - CNF scripted delimited data property is in a separate file.
       - %LOG     - Log settings property, i.e. enabled=1, console=1.
       - TABLE    - SQL related.
       - TREE     - Property is a CNFNode tree containing multiple depth nested children nodes.
       - INCLUDE  - Include properties from another file to this repository.
                    - Included files constances are ignored if are in parent file assigned.
                    - Includes are processed last and not on the spot, so their anons encountered take over precedence.
                    - Include instruction use is not recommended and is as same to as calling the parse method of the parser.
       - INDEX    - SQL related.
       - INSTRUCT - Provides custom new anonymous instruction.
       - VIEW     - SQL related.
       - PLUGIN   - Provides property type extension for the PerlCNF repository.
       - SQL      - SQL related.
       - MIGRATE  - SQL related.
       - MACRO
          1. Value is searched and replaced by a property value, outside the property scripted.
          2. Parsing abruptly stops if this abstract property specified is not found.
          3. Macro format specifications, have been aforementioned in this document. However, make sure that your macro an constant also including the *$* signifier if desired.

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

4. MIGRATE
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

### Scripted Data Related Instructions

1. DATA
    1. Data is specifically parsed, not requiring quoted strings and isn't delimited by new lines alone.
    2. Data rows are ended with the **"~"** delimiter. In the tag body.
    3. Data columns are delimited with the invert quote **"`"** (back tick) making the row.
    4. First column can be taken as the unique and record identity column (UID).
        1. If no UID is set, or specified with # or, 0, ID is considered to be auto-numbered based on data position plus 1, so not to have zero IDs.
        2. When UID is specified, an existing previous assigned UID cannot be overridden, therefore can cause duplicates.
        3. Data processing plugins can be installed to cater and change behavior on this whole concept.
    5. Data is to be updated in storage if any column other than the UID, has its contents changed in the file.
       1. This behavior can be controlled by disabling something like an auto file storage update. i.e. during application upgrades. To prevent user set settings to reset to factory defaults.
       2. The result would then be that database already stored data remains, and only new ones are added. This exercise is out of scope of this specification.

    ```HTML
        <<MyAliasTable<DATA
        01`admin`admin@inc.com`Super User~
        02`chef`chef@inc.com`Bruno Allinoise~
        03`juicy`sfox@inc.com`Samantha Fox~
        >>
    ```

2. FILE
   1. Expects a file name assigned value, file containing actual further CNF DATA rows instructions, separately.
   2. The file is expected to be located next to the config file.
   3. File is to be sequentially buffer read and processed instead as a whole in one go.
   4. The same principles apply in the file as to the DATA instruction CNF tag format, that is expected to be contained in it.

    ```HTML
        <<MyItemsTbl<FILE data_my_app.cnf>
    ```

3. PLUGIN
    1. Plugin instruction is specific outside program that can be run for various configuration task, on post loading of all properties.
        This can be special further.
        1. Further, processing of data collections.
        2. Issuing actions, revalues.
        3. Checking structures, properties and values that are out of scope of the parser.
    2. To a plugin parser itself will be passed to access.
        1. Required attributes are:
            1. package : Path or package name of plugin.
            2. subroutine: Subroutine name to use to pass the parser, after plugin initialization.
            3. property : property to be passed directly, if required, like with data processing.
    3. Requirements are for plugins to work to have the DO_ENABLED=>1 config attribute set.
        1. Plugins currently also will require be last specified in the file, to have access to previous anons that are instructed.

    ```HTML
       /**
        * Plugin instructions are the last one setup and processed,
        * by placing the actual result into the plugins tag name.
        */
        <<processor<PLUGIN>
            package     : DataProcessorPlugin
            subroutine  : process
            property    : employees
        >>
    ```

4. TREE (NEW FEATURE - 20221128)
   1. Will create an CNF property having a CNFNode object, that contains further child nodes or attributes in a tree structure.
        1. This is a hash of anons for attributes and a list of further nodes, all having is of one value.
        2. Property can have its value, contain attributes, and also other properties within.
            1. The property markup in the tree script is called body, and follows the PerlCNF style.
               The difference is that both ' **<,>** ' and ' **[,]** ' are signifiers for the property or multiline value, start and end tags.
                1. All tags require to be on a line of their own.
                2. Current algorithm uses sub buffering to parse each properties body.
                    So deeply nesting an large property body is not recommended and also not suitable for encapsulating there data.
                3. An opening tag is opened being surround with the same signifier into the direction of the property body.
                4. The closing tag is in the opposite direction same signifiers.
                    - **[sesame[** I am an open and closed value now, nothing you can do about it (X|H)TML! **]sesame]** 
        3. The node characteristic is that each sub property is linked to its parent property
           1. This is contained in the ' **@** ' attribute.
           2. Node characteristic is also the tree can be searched via path.
           3. Perl doesn't require type casting and conversion for node values, but for only few rare occasions.
        4. All attributes and sub properties have to have unique names.
            1. Emphasis of having uniquely named properties is to avoid having a tree to be used as an collection.
            2. A property can have its contained collection however, which are multiple sub properties placed into an ' **@@** ' field or attribute.
        5. However deeply nested in. The contained attributes and other properties are assigned and accessed by a path statement.
        6. Attributes can be either assigned with an ' **:** ' or ' **=** ' signifier, no quotes are needed; unless capturing space.
            - Attributes must specified on a single line.
            - Future versions might provide for allowing to assign similar as property values, with the multiline value tag.
   2. The TREE instruction will create an CNFNode object assigned to an unique anon.
        1. The value of an property is delimited with an [ **#** ] tag as start, end [ **/#** ] as the ending.
            - Each properties start and end tag must stand and be on its own line, withing the body.
   3. Tree can contain links to other various properties, anons, that means also to other trees then the current one.
        1. A link (pointer) to an outside anon or property is specified in form of -> ```[*[ {path/name} ]*]```.
        2. It is not recommended to make circular links, or to priorities properties themselves containing links.
        3. To aid parsing priority a parse special instruction can be used if for example linking trees.
            1. Specified the best just after the tree instruction as -> ```<<...<TREE> _HAS_PROCESSING_PRIORITY_```.
            2. This is currently a TREE instruction only inbuilt option in PerlCNF, for the CNFNodes individuals scripts order of processing.
   4. Tree Format Example:

        ```HTML
        <<APP<My Nice Application by ACME Wolf PTY>>

        <<doc<TREE>
        <*<APP>*>
        thread: 28
        title = My Application
            <client<
                address: 192.168.1.64
                [paths[
                    [#[
                        ./dev
                        ./sources
                    ]#]
                ]paths]
            >client>
        >>
        ```

## Sample Perl Language Usage

Quick Jump: [Introduction](#introduction) | [CNF Collections Formatting](#cnf-collections-formatting) | [Instructions & Reserved Words](#instructions-and-reserved-words) | [Scripted Data Related Instructions](#scripted-data-related-instructions) | [CNF Tag Formats](#cnf-tag-formats)

1. *DO*
   1. CNF DO instruction is *experimental*, purely perl programming language related.
   2. It provides perl code evaluation during parsing giving also access to parser and its variables as DO's there sequentially appear.
   3. It is recommended to comment out this feature, if never is to be used or found not safe to have such thing enabled.
   4. This if named are assigned as anons, with the last processed value as the return. Making them evaluated and processed ever only once.

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
<<list<ls -lh dev|sort>>>
<<<CONST
$RELEASE_VER = 1.0
$APP_NAME="My Application Sample"
>>>

```

***

   Document is from project ->  <https://github.com/wbudic/PerlCNF/>

   An open source application.

<center>Sun Stage - v.2.8 2024</center>

