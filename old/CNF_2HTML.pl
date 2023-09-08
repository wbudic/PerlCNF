#!/usr/bin/perl
use v5.34; #use diagnostics;
use warnings;
use Try::Tiny;
use Exception::Class ('CNFParserException');

#LanguageServer doesn't like -> $ENV{'PWD'} settings.json should not be set for it withn an pwd.
use lib "system/modules";
#use lib "system/modules";
require CNFParser;
no strict "refs";
my $cnf = new CNFParser('CNF2HTML.cnf');
my $html = CNF2HTML->new();




say $html->generate($cnf);
say $cnf->anon('page');

package CNF2HTML {
  use CGI;


  sub new { my ($this) = shift;
    return bless {cgi=>CGI->new()}, $this;
  }

  sub generate {
      my ($this,$cnf) = @_;
      my $cgi = $this->{cgi};
      my $ret = $cgi->header( -charset => "UTF-8");
      my @sty = (); my @js = ();
      foreach my $itm(@{$cnf->property('@StyleSheets')}){
          push @sty, { -type => 'text/css', -src => $itm }
      }
      foreach (@{$cnf->property('@JavaScripts')}){
           push @js, {-type => 'text/javascript', -src => $_ }
      }

      $ret .= $cgi->start_html(-title=>$cnf->constant('$APP_NAME'), -script => \@js,  -style => \@sty);
      #           $cgi->start_html(-title=>$cnf->constant('$APP_NAME'),
      # -script =>
      #           { -type => 'text/javascript', -src => 'wsrc/main.js' },
      # -style => { -type => 'text/css', -src => 'wsrc/main.css' });


      foreach my $p($cnf->list('section')){
        $ret .= $p->{val};
      }

        $ret .= $cgi->end_html;
      return $ret;
  }


}