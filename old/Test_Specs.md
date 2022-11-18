# Test Driven Development For PerlCNF


## Introduction

Test driven development for PerlCNF and other projects, have been completely written from scratch.
It is included with the source of the project, and latest version in maintained and updated only [there](https://github.com/wbudic/PerlCNF).

## Requirements

* Perl and some CPAN Modules
    1. *Term::ANSIColor*
        * Our reports and output is in deluxe terminal color.
    2. *Date::Manipi*
        * For the comprehensive and rich, date manipulation, formatting and calculation.

## Crucial Files and Usage

1. [](./tests/TestManager.pm) (Do not modify)
    * Main manager and handler for the test cases.
2. [tests/template_for_new_test.pl](./tests/template_for_new_test.pl)
    * Use a copy of this file to start a new test file, full of test cases.
    * Prefix the name of the copy with test{your_new_name}.pl in the [tests directory](tests)
    * You can run debug this file now personally.
3. [tests/testAll.pl](tests/testAll.pl) (It is not recommended to modify this file)
    * Run this file to automatically detect all the test*.pl files, checking if all is smooth in your perl project.
    * Example how to run: ```perl ./tests/testAll.pl```, it is simple.

## Testing Concept

1. Each test file contains test cases within an try{}catch() clause.
   * This employs a test manager to handle, evaluate and control, all the aspects of the tests.
   * This also includes processing and reaction on any possible encountered errors or exceptions.
2. Testing output can have also subcases to make reporting and status more readable and apparent.
3. On crucial exceptions the manager will popup and list partial source code at location of error.
   * This was also an important reason of this testing system to make troubleshooting that much easier.
4. Code warnings and issues, are gathered and neatly reported, as the fiddly bonus to any other possible problems.

## Future Plans & Road Map

1. Configuration and more features might become part of this testing framework.
   * Using the PerlCNF concept.
2. Extra features and methods will spring up, and be enhanced.

---
See also:  [Configuration Network File Format Specifications](CNF_Specs.md)

---
   This document v.1.0 is from project ->  (https://github.com/wbudic/PerlCNF)
   An open source application under <https://choosealicense.com/licenses/isc/>
   Exception, this specification file is not to be modified from an third party.
