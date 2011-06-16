package SL::Helper::Csv::Error;

use strict;

sub new {
  my $class = shift;
  bless [ @_ ], $class;
}

sub raw_input { $_->[0] }
sub code      { $_->[1] }
sub diag      { $_->[2] }
sub col       { $_->[3] }
sub line      { $_->[4] }

1;
