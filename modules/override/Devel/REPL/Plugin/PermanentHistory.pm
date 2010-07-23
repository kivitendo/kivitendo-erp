package Devel::REPL::Plugin::PermanentHistory;

use Moose::Role;
use namespace::clean -except => [ 'meta' ];
use File::Slurp;
use Data::Dumper;

has 'history_file' => ( is => 'rw' );

sub load_history {
  my $self = shift;
  my $file = shift;

  $self->history_file( $file );

  return unless $self->history_file && -f $self->history_file;

  my @history =
    map { chomp; $_ }
    read_file($self->history_file);
#  print  Dumper(\@history);
  $self->history( \@history );
  $self->term->addhistory($_) for @history;
}

before 'DESTROY' => sub {
  my $self = shift;

  return unless $self->history_file;

  write_file $self->history_file,
    map { $_, $/ }
    grep $_,
    grep { !/^quit\b/ }
    @{ $self->history };
};

1;

