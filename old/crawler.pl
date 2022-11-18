#!/usr/bin/env perl
use 5.34.0;
#use lib "lib", "../lib";
no warnings qw(experimental::signatures);
##no critic qw(Subroutines::RequireFinalReturn)
##no critic qw(TestingAndDebugging::RequireUseWarnings)
use Parallel::Pipes::App;

=head1 DESCRIPTION

This script crawles a web page, and follows links with specified depth.

You can easily change

  * a initial web page
  * the depth
  * how many crawlers

Moreover if you hack Crawler class, then it should be easy to implement

  * whitelist, blacklist for links
  * priority for links

=cut



package URLQueue {

use constant WAITING => 1;
use constant RUNNING => 2;
use constant DONE    => 3;

    sub new  { my ($class, %option)=@_;
        return bless {
                max_depth => $option{depth},
                queue => { $option{url} => { state => WAITING, depth => 0 } },
        }, $class;
    }
    sub get {my ($self)=@_;
        my $queue = $self->{queue};
        map { +{ url => $_, depth => $queue->{$_}{depth} } }
            grep { $queue->{$_}{state} == WAITING } keys %$queue;            
    }
    sub set_running  {my ($self,$task)=@_;
        $self->{queue}{$task->{url}}{state} = RUNNING;
    }
    sub register {my ($self,$result)=@_;
        my $url   = $result->{url};
        my $depth = $result->{depth};
        my $next  = $result->{next};
        $self->{queue}{$url}{state} = DONE;
        return if $depth >= $self->{max_depth};
        for my $n (@$next) {
            next if exists $self->{queue}{$n};
            $self->{queue}{$n} = { state => WAITING, depth => $depth + 1 };
        }
    }
}

package Operation {
    use Web::Scraper;
    use LWP::UserAgent;
    use Time::HiRes ();
    sub new  {  my ($class)=@_;
        bless {
            http => LWP::UserAgent->new(timeout => 5),
            scraper => scraper { process '//a', 'url[]' => '@href' },
        }, $class;
    }
    sub crawl { my  ($self, $url, $depth) = @_;

        my ($res, $time) = $self->_elapsed(sub { $self->{http}->get($url) });

        if ($res->is_success and $res->content_type =~ /html/) {
            my $r = $self->{scraper}->scrape($res->decoded_content, $url);
            warn "[$$] ${time}sec \e[32mOK\e[m crawling depth $depth, $url\n";
            my @next = grep { $_->scheme =~ /^https?$/ } @{$r->{url}};
            return {url => $url, depth => $depth, next => \@next};
        } else {
            my $error = $res->is_success ? "content type @{[$res->content_type]}" : $res->status_line;
            warn "[$$] ${time}sec \e[31mNG\e[m crawling depth $depth, $url ($error)\n";
            return {url => $url, depth => $depth, next => []};
        }

    }
    sub _elapsed  { my  ($self, $cb) = @_;
        my $start = Time::HiRes::time();
        my $r = $cb->();
        my $end = Time::HiRes::time();
        return $r, sprintf("%5.3f", $end - $start);
    }
}

my $crawler = Operation->new;
my $queue = URLQueue->new(url => "http://media.telstra.com.au/home.html", depth => 2);
my @task = $queue->get;

Parallel::Pipes::App->run(
    num => 5,
    tasks => \@task,    
    before_work => sub  {  my  ($task) = @_;
        $queue->set_running($task);
    },

    work => sub  {my ($task) = @_; 
                 $crawler->crawl($task->{url}, $task->{depth}); 
            },

    after_work =>  sub  {  my  ($result) = @_;
        $queue->register($result);
        @task = $queue->get;
    },
);
