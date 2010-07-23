package Devel::REPL::Plugin::AutoloadModules;

use Moose::Role;
use namespace::clean -except => [ 'meta' ];
use Data::Dumper;

has 'autoloaded' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );

my $re = qr/Runtime error: Can.t locate object method "\w+" via package "\w+" \(perhaps you forgot to load "(\w+)"\?\)/;
around 'execute' => sub {
  my $orig = shift;
  my $self = shift;

  my @re = $self->$orig(@_);                           # original call

  return @re unless defined $re[0] && $re[0] =~ /$re/; # if there is no "perhaps you forgot" error, just return
  my $module = $1;                                     # save the missing package name

  return @re if $self->autoloaded->{$module};          # if we tried to load it before, give up and return the error

  $self->autoloaded->{$module} = 1;                    # make sure we don't try this again
  $self->eval("use SL::$module");                      # try to load the missing module

  @re = $self->$orig(@_);                              # try again

  return @re;
};

1;
