package SL::Git;

use strict;
use warnings;

use parent qw(Rose::Object);

use Carp;
use List::Util qw(first);

sub is_git_installation {
  my ($self) = @_;

  return $self->git_exe && -d ".git" && -f ".git/config" ? 1 : 0;
}

sub git_exe {
  my ($self) = @_;

  return $self->{git_exe} if $self->{_git_exe_search};

  $self->{_git_exe_search} = 1;
  $self->{git_exe}         = first { -x } map { "${_}/git" } split m/:/, $ENV{PATH};

  return $self->{git_exe};
}

sub get_log {
  my ($self, %params) = @_;

  croak "No git executable found" if !$self->git_exe;

  my $since_until = join '..', $params{since}, $params{until};
  my $in          = IO::File->new($self->git_exe . qq! log --format='tformat:\%H|\%an|\%ae|\%ai|\%s' ${since_until} |!);

  if (!$in) {
    no warnings 'once';
    $::lxdebug->message(LXDebug::WARN(), "Error spawning git: $!");
    return ();
  }

  my @log = grep { $_ } map { $self->_parse_log_line($_) } <$in>;
  $in->close;

  return @log;
}

sub _parse_log_line {
  my ($self, $line) = @_;

  chomp $line;

  my @fields = split m/\|/, $line, 5;
  return undef unless scalar(@fields) == 5;

  my %commit     = (
    hash         => $fields[0],
    author_name  => $fields[1],
    author_email => $fields[2],
    subject      => $fields[4],
  );

  if ($fields[3] =~ m/^(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)\s+?([\+\-]?\d+)?$/) {
    $commit{author_date} = DateTime->new(year => $1, month => $2, day => $3, hour => $4, minute => $5, second => $6, time_zone => $7);
  }

  return \%commit;
}

1;
