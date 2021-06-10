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
    * Scalars
    * Arrays
    * Hashes
  * Use of **my** is the preferred declaration. As **local** will not create a private variable, contained to the subroutine.
    * **local** variables are dynamic variables, and are available to other blocks and visible to other called subroutines within the block where declared.

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
      * Some might say seeing this, oh life is not easy in the Perl suburbs of code, put it can get more complicated.The container can be hashref type of list, where each item is a unique property, searchable and nested further.
      * Good saying is also keep it short smart, when bloated is stupid. Iteration method can be passed an anonymous subroutine, that out of scope of the container, performs individual action on items in the container. The container contains, and by purpose restricts or allows, what ever implementation you fit as appropriate with it.
      *

    ```Perl
       
        my $container = Container->create(); 
        ...
        $container->iterate(sub {print "Reached Property -> ".$_->name(),"\n"});

    ```

***
**Released: v.1.0 Date:20210610**
***
   This document has been written by Will Budic and is from the project ->  <https://github.com/wbudic/PerlCNF>

   
   
   The disclaim, ideas and statements encountered are of personal opinion and facts. Acquired from personal study and experience.
   Author, removes him self from any responsibility for any third party accepting or implementing the aforementioned document into practice.
   Amendments and critique are welcomed, as this is an open public letter document. 
   
   However, No permission has been given, to publishing, copy parts of this document,
    outside of its project location. 
   The only permission been given by the author, is to remove this document from after acquiring any other project code or files, which are open source.