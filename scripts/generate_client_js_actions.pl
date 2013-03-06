#!/usr/bin/perl

use strict;
use warnings;

use File::Slurp;
use List::Util qw(first max);

my $file_name = (first { -f } qw(SL/ClientJS.pm ../SL/ClientJS.pm)) || die "ClientJS.pm not found";
my @actions;

foreach (read_file($file_name)) {
  chomp;

  next unless (m/^my \%supported_methods/ .. m/^\);/);

  push @actions, [ 'action',  $1, $2 ] if m/^\s+([a-zA-Z]+)\s*=>\s*(\d+),$/;
  push @actions, [ 'comment', $1     ] if m/^\s+#\s+(.+)/;
}

my $longest   = max map { length($_->[1]) } grep { $_->[0] eq 'action' } @actions;
my $first     = 1;
my $output;

#      else if (action[0] == 'hide')        $(action[1]).hide();
foreach my $action (@actions) {
  if ($action->[0] eq 'comment') {
    print "\n" unless $first;
    print "      // ", $action->[1], "\n";

  } else {
    my $args = $action->[2] == 1 ? '' : join(', ', map { "action[$_]" } (2..$action->[2]));

    printf('      %s if (action[0] == \'%s\')%s $(action[1]).%s(%s);' . "\n",
           $first ? '    ' : 'else',
           $action->[1],
           ' ' x ($longest - length($action->[1])),
           $action->[1],
           $args);
    $first = 0;
  }
}

printf "\n      else\%sconsole.log('Unknown action: ' + action[0]);\n", ' ' x (4 + 2 + 6 + 3 + 4 + 2 + $longest + 1);
