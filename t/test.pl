#!/usr/bin/perl -X

use strict;

use Data::Dumper;
use File::Find ();
use Test::Harness qw(runtests execute_tests);

BEGIN {
  $ENV{HARNESS_OPTIONS} = 'j:c';
  unshift @INC, 'modules/override';
  push    @INC, 'modules/fallback';
}

sub find_files_to_test {
  my @files;
  File::Find::find(sub { push @files, $File::Find::name if (-f _) && m/\.t$/ }, 't');
  return @files;
}

my (@tests_to_run, @tests_to_run_first);

if (@ARGV) {
  @tests_to_run       = @ARGV;

} else {
  @tests_to_run_first = qw(t/000setup_database.t);
  my %exclude         = map  { ($_ => 1)     } @tests_to_run_first;
  @tests_to_run       = grep { !$exclude{$_} } sort(find_files_to_test());
}

if (@tests_to_run_first) {
  my ($total, $failed) = execute_tests(tests => \@tests_to_run_first);
  exit(1) unless !$total->{bad} && (0 < $total->{max});
}

runtests(@tests_to_run);
