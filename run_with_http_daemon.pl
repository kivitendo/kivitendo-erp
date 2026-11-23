#!/usr/bin/perl

use strict;

BEGIN {
  use FindBin;

  #chdir('..');

  unshift(@INC, $FindBin::Bin . '/modules/override'); # Use our own versions of various modules (e.g. YAML).
  push   (@INC, $FindBin::Bin . '');                 # '.' will be removed from @INC soon.
}

use HTTP::Daemon;
use HTTP::Status;

use SL::Dispatcher;
use SL::Request;
use Capture::Tiny ':all';
use Encode qw(decode encode);



#use Mojolicious::Lite;
##Mojolicious->new( mode => 'developer' );
##app->mode( 'developer');
#
#our %CACHE;
#
##any '/:any' => sub {
##    my $self = shift;
##    my $param = $self->param('any');
##    my $result = { reqtime => time, param => $param, number => rand };
##    my $path = $self->req->url->path->to_string;
##    #$CACHE{$path} //= $result;
##
##    print $path . "\n";
##    $self->render( json => $result );
##};
#
#app->hook( before_dispatch => sub {
#    my $c = shift;
#    my $path = $c->req->url->path->to_string;
#
#    $ENV{SCRIPT_NAME}  = $c->req->url->path->to_string;
#    $ENV{QUERY_STRING} = $c->req->url->query->to_string;
#
#    #print "SCRIPT $ENV{SCRIPT_NAME}\nQUERY $ENV{QUERY_STRING}\n$path\n\n";
#
#    our $dispatcher = SL::Dispatcher->new('CGI');
#    $dispatcher->pre_startup;
#    $dispatcher->handle_request;
#
#    #$c->render;
#    $c->res->headers->content_type('text/plain');
#    $c->res->body('Hello World!');
#    $c->rendered(200);
#} );
#app->secrets([42])->start;

sub prevent_directory_traversal {
  my ($path) = @_;

  my @clean;
  my @raw = split(m{/}, $path);
  foreach my $seg (@raw) {
    if ($seg eq '..') {
      pop @clean;

    } elsif ($seg eq '' || $seg eq '.') {

    } else {
      push @clean, $seg;
    }
  }

  return join('/', @clean);
}

our $dispatcher = SL::Dispatcher->new('FastCGI');
$dispatcher->pre_startup_setup;
#SL::FCGIFixes::apply_fixes();
$dispatcher->pre_startup_checks;
$::REQ_BODY = '';

my $d;
$d = HTTP::Daemon->new(
         #LocalAddr => 'www.thisplace.com',
         LocalPort => 8080,
         ReuseAddr => 1,
     ) or die "$!";

SERVE: while (my $c = $d->accept) {
    while (my $r = $c->get_request) {

      # BUG: after several requests with Connection: keep-alive, each new request takes very long (a few minutes)
      $c->force_last_request;

      print "req uri " . $r->uri->path . "\n";
      if (! ($r->uri->path =~ m{[a-z]+\.pl})) {
        my $filename = "public/" . prevent_directory_traversal($r->uri->path);
        if  (-f $filename) {
          $c->send_file_response($filename);
          #print "static $filename\n";
          next;
        }
        print "forbidden " . $r->uri->path . "\n";
        $c->send_error(RC_NOT_FOUND);
        next;
      }
      $ENV{SCRIPT_NAME}  = $r->uri->path;
      $ENV{QUERY_STRING} = $r->uri->query;
      $ENV{CONTENT_TYPE}          = $r->header('Content-Type');
      $ENV{HTTP_X_REQUESTED_WITH} = $r->header('X-Requested-With');
      $ENV{HTTP_USER_AGENT}       = $r->header('User-Agent');
      $ENV{HTTP_COOKIE}           = $r->header('Cookie');
      $ENV{HTTP_REFERER}          = $r->header('Referer');
      $ENV{REQUEST_URI}  = $r->uri->path;
      $ENV{HTTP_HOST}      = $r->header('Host');
      #$ENV{SERVER_ADDR}

      $::REQ_BODY = $r->content;

      #binmode STDOUT, ":encoding(UTF-8)";
      binmode STDOUT, ":utf8";   # treat output as already-encoded UTF-8 without performing conversion
      #binmode STDOUT, ":raw";
      my ($stderr, $stdout);

      ($stdout, $stderr) = capture {
        $dispatcher->handle_request;
      };

      my $status = 200;
      my @header;
      if (($stdout =~ m/Set-Cookie: ([^\r]+)\r/)) {
        push @header, ('Set-Cookie' => $1);
      }
      if (($stdout =~ m/Status: 302/) && ($stdout =~ m/Location: (.+)(?:\r)/)) {
        $status = 302;
        push @header, (Location => $1);
        #print "redirect $1\n";
      } else {
        if (($stdout =~ m/^.*\r\n\r\n\{/s)) {
        push @header, ('content-type' => 'application/json; charset=UTF-8');
        } else {
        push @header, ('content-type' => 'text/html');
        }
      }
      $stdout =~ s/^.*\r\n\r\n//s;
      #push @header, ('content-length' => length($stdout));
      my $body = encode('UTF-8', $stdout);
      #my $body = decode('UTF-8', encode('UTF-8', $stdout));
      #my $body = $stdout;
      my ($code, $msg, $header, $content) = ($status, '', [@header], $body);
      my $res = HTTP::Response->new( $code, $msg, $header, $content );
      $c->send_response($res);
      print $stderr;


      if ($dispatcher->restart_after_request) {
        print "Program modifications detected. Terminating.\n";
        last SERVE;
      }
    }
    $c->close;
    undef($c);
}



1;


# Synopsis:
# perl run_with_http_daemon.pl
# Run in Perl debugger:
# perl -d run_with_http_daemon.pl
