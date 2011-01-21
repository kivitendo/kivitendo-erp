#!/usr/bin/perl

use strict;
use File::Find;
use LWP::Simple;
use Test::More tests => 1;
use URI::Find;

my @fails;

my $finder = URI::Find->new(sub {
  my ($uri_obj, $uri_text) = @_;
  $uri_text =~ s/^\<//;
  $uri_text =~ s/\>$//;

  push @fails, "$uri_text in file $File::Find::name"
    if !defined get($uri_text);

  return $_[1];
});

find(sub {
  open(FH, $File::Find::name) or return;
  my $text;
  { local $/; $text = <FH>; }

  $finder->find(\$text);

  }, "."
);

if (@fails) {
  ok(0, join "\n", @fails);
} else {
  ok(1, "no broken links found");
}
