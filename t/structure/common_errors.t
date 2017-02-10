#!/usr/bin/perl

use strict;
use threads;
use lib 't';
use Support::Files;
use Sys::CPU;
use Thread::Pool::Simple;

my ($testcount);

BEGIN {
  $testcount = scalar @Support::Files::testitems;
}

use Test::More tests => $testcount;

# Capture the TESTOUT from Test::More or Test::Builder for printing errors.
# This will handle verbosity for us automatically.
my $fh;
{
  local $^W = 0;                # Don't complain about non-existent filehandles
  if (-e \*Test::More::TESTOUT) {
    $fh = \*Test::More::TESTOUT;
  } elsif (-e \*Test::Builder::TESTOUT) {
    $fh = \*Test::Builder::TESTOUT;
  } else {
    $fh = \*STDOUT;
  }
}

my @testitems = @Support::Files::testitems;

# at last, here we actually run the test...

my @common_errors = ([ '^\s*my\s+%[a-z0-9_]+\s*=\s*shift' ],
                     [ '^\s*my\s+\(.*\)\s*=\s*shift'      ],
                     [ '^\s*my\s+\$[^=]*=\s*@_'           ],
                     [ '@[a-z0-9_]+->'                    ],
                     [ 'uft8'                             ],
                     [ '\$slef'                           ],
                    );

sub test_file {
  my ($file) = @_;
  $file =~ s/\s.*$//;           # nuke everything after the first space (#comment)
  return if (!$file);           # skip null entries

  if (open (FILE, $file)) {     # open the file for reading
    $_->[1] = [] foreach @common_errors;

    my $line_number = 0;
    while (my $file_line = <FILE>) {
      $line_number++;

      foreach my $re (@common_errors) {
        push @{ $re->[1] }, $line_number if $file_line =~ /$re->[0]/i;
      }
    }

    close (FILE);

    my $errors = join('  ', map { $_->[0] . ' (' . join(' ', @{ $_->[1] }) . ')' } grep { scalar @{ $_->[1] } } @common_errors);
    if ($errors) {
      ok(0,"$file: found common errors: $errors");
    } else {
      ok(1,"$file does not contain common errors");
    }
  } else {
    ok(0,"could not open $file for common errors check --WARNING");
  }
}

my $pool = Thread::Pool::Simple->new(
  min    => 2,
  max    => Sys::CPU::cpu_count() + 1,
  do     => [ \&test_file ],
  passid => 0,
);

$pool->add($_) for @testitems;

$pool->join;

exit 0;
