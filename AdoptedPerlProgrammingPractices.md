# Adopted Perl Programming Practices

APPP, Similar to the jargon of Internet Marketings strategy of 3 P's:


1. **Permission** – to increase your response rate, get permission from people first before you send them email marketing messages.
1. **Personality** – let your personality shine through in all your marketing communications to better connect with your ideal clients.
1. **Personalization** – narrow your service offerings to a very specialized niche market to make it easier for potential clients to find you.

This document highlights my personal adopted practices to efficiently and uniformly use the Perl language, through to all the code and future revisions.
As the number of projects mount, and experience and the encountered other best practices come to light. Hopefully and possibly, this document will be updated and worked on to reflect, give answers or remind. Why something is implemented in a particular way, and to some readers for god sake, also why?

## Perl Objects

Perl objects start with **variables** progress to **blocks** where variables are used in a expression context as encountered from one statement to next.
Grouped and reused operations are called **subroutines**. Subroutines choice of use is, is incredibly in many ways flexible further. Where they can be void, functions and even method like, when used in a **package** object. Beside packaging your variables and subroutines for reuse into a single object. It is worth mentioning, that packages can be placed into modules, for further better organization, however modules are not objects.

### Variables

* Global variables are package variables, the most primitive and default package is called ```main::```. Your script runs in it, I can bet on it.
* Lexical variables are part of a block, their life starts in it and ends, declared by **my**, **local** or **state**, and are initialized by the type of data they represent.
  * Basic Variable Data Types are:
    * `$` Scalars
    * `@` Arrays
    * `%` Hashes
  * Use of **my** is the preferred declaration. As **local** will not create a private variable, contained to the subroutine.
    * **local** variables are dynamic variables, and are available to other blocks and visible to other called subroutines within the block where declared.
* Special variables, inbuilt, reserved, magical, these are part also of the Perl language, and are suggested reading about.
  * These are not covered in this document, and if not familiar with, not a required further reading.
   * Or if still curious here -> [https://perldoc.perl.org/perlvar]
* The main benefit of Perl is actually that it isn't strictly typed, and scalars will automatically best can convert, outcome for your expressions, declarations.
  * Remember it is designed to be an fast interpreted on the fly language, providing you an flexible way to interact and work in a script with behind the scene libraries that are not high level. Making it an excellent candidate for prototyping, testing, implementing algorithm logistics without to be constrained to any needed structures, levels of complex what an external framework implementation requirements is? And where?
  * Has garbage collection, mutability, and one of the actual first kind of functional languages is Perl. It functions, without having to do much setup, configuration or tooling. If you do, it is most likely that you are reinventing the wheel.
  * Good practice is to keep to adopted version of Perl, provided features. And not use experimental features in your scripts, not available to an existing old installation on your network. Rest is its long history. Old code has to be compatible with newer version of the Perl interpreter.

### Subroutines

Subroutines can also be in nature anonymous, clojure. They are fastest accessed without parenthesis.

* Instead of an empty argument list, use the pod signifier **&** that is for subroutines, as this passes the current running block argument list (@_) to them.
  * >i.e.: use ```&foo;``` instead of calling with ``` foo(); ``` is faster and preferred.  
* Arguments to a subroutines are a flat list copy of variables passed. Don't pass globals, and avoid local variables, if you expect them to change by the subroutine.
 
### Methods

Object methods return encapsulate different variable values but structured by same the name. Those variable names must not change, and some times also the variable value is not to be changed form the initialized one, as it is to stay private.

* Package variables are to be private, otherwise forget about it.
* Package objects are to be created by default with an fixed list of names of the variable, in form of a hashtable that is blessed to an instance.
  * Example:
  
    ```Perl
    package Example{
        sub create{
                my ($pck,$args) = @_;
                        
                        bless { 
                                    name => $args->{name}, 
                                    value => $args->{value}?$args->{value}:0,
                        }, $pck;
        }
    }
    my $example = Example->create({name=>"ticket", value=>2.50});

    ```

* Variables of an package object is to have ONE subroutine to deal with setting or getting the value.
  * Unlike in OOP get/set methods, Perl doesn't need two methods. Why make the object bigger? Even if it is only in its initial state.
  * Example:
  
    ```Perl
    package Example{
        ...
        sub name  {shift->{cnt}}
        sub value {my($this, $set)=@_;if($set){$this->{value} = $set};$this->{value}}
    }

    ```

    * In example above the **name** object variable is read only. While **value** is both an true get/setter method rolled into one.

* The parent container to package objects, is to be a separate entity, to which its children don't have access.
* Containers or composites lists of particular type of object should use ```ref(.)``` method, and not function prototypes, that is the function signature approach.
  * Example:
  
    ```Perl
    package Container {
        
        sub create {
            my ($this) = @_;
            bless {items=>()},$this;
        }
        sub add {        
            my ($this,$item) = @_;
            my $r = ;
            if(ref($item) eq 'Example'){
                push (@{$this->{items}}, $item);

            }else{
                die "put $item, not of package type -> Example"
            }        
        }
        sub iterate {
            my ($this,$with) = @_;
            foreach(@{$this->{items}}){
                do $this->$with($_);
            }
        }
    }

    ```

    * Example above creates a flat list or array that can contain only items of a certain package type object.
      * Some might say; seeing this, *oh life is not easy in the Perl suburbs of code*, put it can get more complicated.The container can be hashref type of list, where each item is a unique property, searchable and nested further.
      * Good saying is also keep it short smart, when bloated is stupid. Iteration method can be passed an anonymous subroutine, that out of scope of the container, performs individual action on items in the container. The container contains, and by purpose restricts or allows, what ever implementation you fit as appropriate with it.
      *

    ```Perl
       
        my $container = Container->create(); 
        ...
        $container->iterate(sub {print "Reached Property -> ".$_->name(),"\n"});

    ```

## Expressions and Logic

* Use **references** for passing lists, arrays and hashes if knowing they are further being read only not changed.
  * In your ``main::`` package you have all in front, and know what are you doing, don't you?
  * However, not using references is secure way, to pass to an module a copy of an extremely huge list. With which it can modify and do what ever its munchkins wants. You are right.
* **IF** statements should and can be tested to for the scalar default exclusively.
  * ``if($v){..do something}``
    * It is not needed to test for null, or in Perls parlang which is the value of ``nothing`` or ``0``.
  * Post declaration testing and setting of variables as one liners are encouraged, don't know why someone sees them as an eye sore?
    * The motto is, the less lines of code the better.
    * Example:

     ```perl
      my $flag = 0; $flag = 1 if scalar(@args)>1;
     ```

  * Following is not a **scalar**, so must not to be coded at all as:

     ```perl
      my @arr;
        print "@arr is not declared!" if !@arr;
        @arr=(1 2 3 "check", this, "out", "some elements here are not comma separated but is valid!");
        print "@arr is declared!" if @arr;
     ```

    * Surprisingly to some coders out there, where this fails is on the last ``if`` statement. Which should be written as:
 
     ```perl
        ...
        print "\@arr is declared an empty list!" if scalar @arr == 0;
     ```

* **IF** statements with further curly brace clauses, should be expression based normal logical statements.
  
     ```perl
        if(!@arr){
            print "\@arr is not declared!";
        }
        elsif (scalar @arr == 0){
            print "\@arr is declared but an empty list!"
        }
        else{
            return hollySmokeHereWeGo(\@arr); #We are passing an reference to our @arr.
        }
     ```

## References

* References are only alike with pointers in C, all variable assignments create copies, same is for lists or hashes.
* Dereferencing outside a scope will create a copy for the purpose of the packages scope. To purposely share a packages hash, return it as a hash reference (**\\%**).
  
  ```perl
  package A;
  our $S_ =""; 
  our %HOUSEHOLD = (
      pets => {dogs=>2, cats=>1}
      furniture => {pianos=>1, tables=>3, chairs=>12}
  )sub household {$S_=shift;\%{$HOUSEHOLD{$S_}}};  
  ```

* ``` sub household ``` is known like this as an method of package A. Opening access to the %HOUSEHOLD hash.
* Following examples use static access package directive A::, an object instance i.e. A->new(), will have own copy of all variables and lists, private to the package.
* ``` my $pets1 = A::household(pets); ``` Scalar $pets1 has an hash reference to the inner hash property of the household hash.
* ``` my %pets2 = ${A::household(pets)}; ``` Hash %pets2 is here dereferencing the other packages owning hash, however this creates an copy. Something not possibly wanted.
* ``` $pets1 -> {'pigeons'} = 140 ``` Scalar here adds to referenced  in package A::%{HOUSEHOLD}->%{pets}, a new entry pigeons and the number of them.
* ``` $pets2{'pigeons'} = 180 ``` We can add to the hash copy similar the same, like this, the usual way, things are added to an hash. But A::%{HOUSEHOLD}->%{pets}, would not about it be any more wiser. It will retain its value. And/Or if to copy we added any new entries, would not have a clue about it.
* ``` my %pets3 = %$pets1 ``` is misleading, it creates the current snapshot copy of $pets1, so similar but not same to assigning ``` my %pets3 = ${A::household(pets)}; ```. The later which you most probably want, a shared and packaged nested anonymous hash.

```text
pets => {dogs=>2, cats=>1} <- This is called an anonymous hash when in curly braces. 
As the 'pets' entry is a key, not a variable.

```

```perl
my %hsh  = (a=>'shared'); <-Normal named and declared hash. Allowed to be declared wrongly
 also with curly braces instead of brackets.
my $ref_hsh  = \%std1; 
$ref_hsh -> {a} = 'changed'; <- Magically we changed the value of a via perls inbuilt autovification process.
print (($ref_hsh->{a} eq $hsh{a}) ?"true":"false"); <- prints true.

```

* We pass to subroutines references to an obj, array or hash, when the same is to transform. Example: ``` my @transformed = process(\@myArray); ```.
  * Variable @transformed is quite an obsolete declaration. As it will contain a copy of @myArray if sub process is returning an array.
  * Subroutines that receive and return a list from its scope, will create new ones on the receiving end. This can be avoided. By changing via array reference (**@$**).

```perl

package A{
    sub process {
      my $into_ref_array = shift;
      push @$into_ref_array, "Aaaaa, real good!"
    }
}

my @this_song = ('Push it!'); <-- Notice list type with brackets declaration, it is mistake 
                                  to declare as a protected fixed array 
                                  i.e. with my @this_song = ['Push it!'];
A::process(\@this_song);
say join ' ', @this_song;

Push it! Aaaaa, real good! <- Prints. See -> Salt-N-Pepa - Push It (Official Music Video)

```

* That all said, this is all is happening from script to initial state of default existence of an program flow. To preserve changed states and dynamic data or even objects. This will require persistance and most likely dynamic object creation.

***

### Released: v.1.2 Date:20210629 (v.1.1 Date:20210610)

   This document has been written by Will Budic and is from the project ->  <https://github.com/wbudic/PerlCNF>

>The disclaim, ideas and statements encountered are of personal opinion and facts. Acquired from personal study and experience.
   Author, removes him self from any responsibility for any third party accepting or implementing the aforementioned document into practice.
   Amendments and critique are welcomed, as this is an open public letter document.

>However, No permission has been given, to publishing, copy parts of this document,
    outside of its project location. 
   The only permission been given by the author, is to remove this document from after acquiring any other project code or files, which are open source.