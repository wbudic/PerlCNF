#!/usr/bin/env perl
use 5.34.0;
#use lib "lib", "../lib";
no warnings qw(experimental::signatures);
##no critic qw(Subroutines::RequireFinalReturn)
##no critic qw(TestingAndDebugging::RequireUseWarnings)
use Thread::Pool::Simple;



package Queue {

use constant WAITING => 1;
use constant RUNNING => 2;
use constant DONE    => 3;

    sub new  { my ($class, %option)=@_;
        return bless {                
                max_depth => $option{max_depth},
                queue => { $option{task} => { state => WAITING, depth=>0, target => $option{draw} } },
        }, $class;
    }
    sub get {my ($self)=@_;
        my $queue = $self->{queue};
        map { +{ task => $_, depth => $queue->{$_}{depth} } }
            grep { $queue->{$_}{state} == WAITING } keys %$queue;            
    }
    sub set_running  {my ($self,$task)=@_;
        $self->{queue}{$task->{task}}{state} = RUNNING;       
    }
    sub register {my ($self,$result)=@_;
        my $task  = $result->{task};
        my $depth = $result->{depth};
        my $next  = $result->{next};
        $self->{queue}{$result}{state} = DONE;       
        return if $depth >= $self->{max_depth};
        for my $n (@$next) {
            next if exists $self->{queue}{$n};
            $self->{queue}{$n} = { state => WAITING, depth => $depth + 1 };
        }
    }
}

package Operation {
    use Time::HiRes ();
    sub new  {my ($class, %option)=@_;
        bless {target => $option{target}, last_pick=>""}, $class;
    }
    sub run {my  ($self, $task) = @_;
        
        my $check = 0;                                    
        my @pick = $self->pickSix();
        my @target = @{$self->{target}};
        my $depth = $task->{depth};
        die "Target not set!".scalar(@target) if scalar @target < 5;
        foreach my $n(@target){
            foreach(@pick){++$check if $n == $_}
        }

        # my $lpick = $task->{pick};
        # print "Last pick: @$lpick\n" if defined $lpick;
        
        if($check < 5){#} scalar @pick){
            my @next; $self->{last_pick} = \@pick;
            my $l = @pick - $check;           
            do{
                push @next, {task => $task->{task}, depth => $depth, next => []}
            }while(--$l>0);            
            
            return {task => $task->{task}, pick=>\@pick, depth => $depth+1, next => \@next} 
        }else{
            my @lp;
            @lp = @{$self->{last_pick}} if $self->{last_pick};            
            warn "[$$] \e[32mDONE!\e[m At depth of $depth reached match of $check [@pick]\n";
            warn "[$$] Last pick before it hit this was -> @lp\n";

            #exit;
           return {task => $task->{task}, pick=>\@pick, depth => $depth, next => []}
        }

    }
    # sub _elapsed  { my  ($self, $cb) = @_;
    #     my $start = Time::HiRes::time();
    #     my $r = $cb->();
    #     my $end = Time::HiRes::time();
    #     return $r, sprintf("%5.3f", $end - $start);
    # }

    my @N;
    sub pickSix {        
        $N[$_] = uniqueRandom() for 0..5;
        @N = sort {$a <=> $b} @N;
        #print "[".join(", ", @N), "]\n";
        return @N;
    }
    sub uniqueRandom {        
        my $num; my $l;
        do{ 
            $l=0; $num = 1 + int rand 45; 
            g: for (0..5){if($N[$_]==$num){$l=1;last g;}}
        }while($l);
        return $num;
    }
}

my @last_draw = [2,8,13,16,24,28];
my $pool  = Operation->new(target => @last_draw);
my $queue = Queue->new(task => "pick_number", max_depth=>15, pick=>Operation::pickSix());
my @task  = $queue->get;
my @picks;


my $pool = Thread::Pool::Simple->new(
               min => 3,           # at least 3 workers
               max => 5,           # at most 5 workers
               load => 10,         # increase worker if on average every worker has 10 jobs waiting
               init => [\&init_handle, $arg1, $arg2, ...]   # run before creating worker thread
               pre => [\&pre_handle, $arg1, $arg2, ...]   # run after creating worker thread
               do => [\&runLotto]     # job handler for each worker
               post => [\&post_handle, $arg1, $arg2, ...] # run before worker threads end
               passid => 1,        # whether to pass the job id as the first argument to the &do_handle
               lifespan => 10000,  # total jobs handled by each worker
             );
package Task{
    sub run {my  ($self, $task) = @_;
            
            my $check = 0;                                    
            my @pick = $self->pickSix();
            my @target = @{$self->{target}};
            my $depth = $task->{depth};
            die "Target not set!".scalar(@target) if scalar @target < 5;
            foreach my $n(@target){
                foreach(@pick){++$check if $n == $_}
            }

            # my $lpick = $task->{pick};
            # print "Last pick: @$lpick\n" if defined $lpick;
            
            if($check < 5){#} scalar @pick){
                my @next; $self->{last_pick} = \@pick;
                my $l = @pick - $check;           
                do{
                    push @next, {task => $task->{task}, depth => $depth, next => []}
                }while(--$l>0);            
                
                return {task => $task->{task}, pick=>\@pick, depth => $depth+1, next => \@next} 
            }else{
                my @lp;
                @lp = @{$self->{last_pick}} if $self->{last_pick};            
                warn "[$$] \e[32mDONE!\e[m At depth of $depth reached match of $check [@pick]\n";
                warn "[$$] Last pick before it hit this was -> @lp\n";

                #exit;
            return {task => $task->{task}, pick=>\@pick, depth => $depth, next => []}
            }

        }
        # sub _elapsed  { my  ($self, $cb) = @_;
        #     my $start = Time::HiRes::time();
        #     my $r = $cb->();
        #     my $end = Time::HiRes::time();
        #     return $r, sprintf("%5.3f", $end - $start);
        # }

        my @N;
        sub pickSix {        
            $N[$_] = uniqueRandom() for 0..5;
            @N = sort {$a <=> $b} @N;
            #print "[".join(", ", @N), "]\n";
            return @N;
        }
        sub uniqueRandom {        
            my $num; my $l;
            do{ 
                $l=0; $num = 1 + int rand 45; 
                g: for (0..5){if($N[$_]==$num){$l=1;last g;}}
            }while($l);
            return $num;
        }
    }
}  

Parallel::Pipes::App->run(
    num => 5,
    tasks => \@task,    
    before_work => sub  {  my  ($task) = @_;
        $queue->set_running($task);       
    },

    work => sub  {my ($task) = @_;     
    return $pool->run($task);
    },

    after_work =>  sub  {  my  ($result) = @_;        
        $queue->register($result);        
        push @picks, $result->{pick};
        @task = $queue->get;
    },
);

foreach my $a(reverse @picks){print "pick: ".  join(", ", @$a), "\n"}

