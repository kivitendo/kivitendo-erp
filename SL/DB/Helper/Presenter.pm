package SL::DB::Helper::Presenter;

use strict;

sub new {
  # lightweight: 0: class, 1: object
  bless [ $_[1], $_[2] ], $_[0];
}

sub AUTOLOAD {
  our $AUTOLOAD;

  my ($self, @args) = @_;

  my $method = $AUTOLOAD;
  $method    =~ s/.*:://;

  return if $method eq 'DESTROY';

  eval "require $self->[0]";

  splice @args, -1, 1, %{ $args[-1] } if @args && (ref($args[-1]) eq 'HASH');

  if (my $sub = $self->[0]->can($method)) {
    return $sub->($self->[1], @args);
  }
}

sub can {
  my ($self, $method) = @_;
  eval "require $self->[0]";
  $self->[0]->can($method);
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::Helper::Presenter - proxy class to allow models to access presenters

=head1 SYNOPSIS

  # assuming SL::Presenter::Part exists
  # and contains a sub link_to($class, $object) {}
  SL::DB::Part->new(%args)->presenter->link_to

=head1 DESCRIPTION

When coding controllers one often encounters objects that are not crucial to
the current task, but must be presented in some form to the user. Instead of
recreating that all the time the C<SL::Presenter> namepace was introduced to
hold such code.

Unfortunately the Presenter code is designed to be stateless and thus acts _on_
objects, but can't be instanced or wrapped. The early band-aid to that was to
export all sub-presenter calls into the main presenter namespace. Fixing it
would have meant accessing presenter functions like this:

  SL::Presenter::Object->method($object, %additional_args)

which is extremely inconvenient.

This glue code allows C<SL::DB::Object> instances to access routines in their
presenter without additional boilerplate. C<SL::DB::Object> contains a
C<presenter> call for all objects, which will return an instance of this proxy
class. All calls on this will then be forwarded to the appropriate presenter.

=head1 INTERNAL STRUCTURE

The created proxy objects are lightweight blessed arrayrefs instead of the
usual blessed hashrefs. They only store two elements:

=over 4

=item * The presenter class

=item * The invocing object

=back

Further delegation is done with C<AUTOLOAD>.

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
