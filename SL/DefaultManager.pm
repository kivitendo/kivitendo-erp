package SL::DefaultManager;

use strict;

use SL::Util qw(camelify);
use List::Util qw(first);

my %manager_cache;

sub new {
  my ($class, @defaults) = @_;
  bless [ @defaults ], $class;
}

sub _managers {
  my ($self) = @_;

  map { $self->_get($_) } @$self;
}

sub _get {
  my ($class, $name) = @_;

  return if !$name;

  $manager_cache{$name} ||= do {
    die "'$name' doesn't look like a default manager." unless $name =~ /^\w+$/;

    my $package = 'SL::DefaultManager::' . camelify($name);

    eval "require $package; 1" or die "could not load default manager '$package': $@";

    $package->new;
  }
}

sub AUTOLOAD {
  our $AUTOLOAD;

  my ($self, @args) = @_;

  my $method        =  $AUTOLOAD;
  $method           =~ s/.*:://;
  return if $method eq 'DESTROY';

  my $manager = first { $_->can($method) } $self->_managers;

  return $manager ? $manager->$method : @args;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DefaultManager - sets of defaults for use outside of clients

=head1 SYNOPSIS

  # during startup
  my $defaults = SL::DefaultManager->new($::lx_office_conf{default_manager});

  # during tests
  my $defaults = SL::DefaultManager->new('swiss');

  # in consuming code
  # will return what the manager provides, or the given value if $defaults does
  # not handle dateformat
  my $dateformat = $defaults->dateformat('dd.mm.yyyy');

  # have several default managers for different tasks
  # if polled the first defined response will win
  my $defaults = SL::DefaultManager->new('swiss', 'mobile', 'point_of_sale');

=head1 DESCRIPTION

TODO

=head1 FUNCTIONS

TODO

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
