package SL::Template::Plugin::P;

use base qw( Template::Plugin );

use SL::Presenter;
use SL::Presenter::EscapedText;

use strict;

sub new {
  my ($class, $context, @args) = @_;

  return bless {
    CONTEXT => $context,
  }, $class;
}

sub escape {
  my ($self, $string) = @_;
  return SL::Presenter::EscapedText->new(text => $string);
}

sub AUTOLOAD {
  our $AUTOLOAD;

  my ($self, @args) = @_;

  my $presenter     = SL::Presenter->get;
  my $method        =  $AUTOLOAD;
  $method           =~ s/.*:://;

  return '' if $method eq 'DESTROY';

  if (!$presenter->can($method)) {
    $::lxdebug->message(LXDebug::WARN(), "SL::Presenter has no method named '$method'!");
    return '';
  }

  splice @args, -1, 1, %{ $args[-1] } if @args && (ref($args[-1]) eq 'HASH');

  $presenter->$method(@args);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Template::Plugin::P - Template plugin for the presentation layer

=head1 SYNOPSIS

  [% USE P %]

  Customer: [% P.customer(customer) %]

  Linked records:
  [% P.grouped_record_list(RECORDS) %]

=head1 FUNCTIONS

=over 4

=item C<AUTOLOAD>

All unknown functions called on C<P> are forwarded to functions with
the same name in the global presenter object.

The presenter's functions use hashes for named-argument
passing. Unfortunately L<Template> groups named arguments into hash
references. This makes mixing intentional hash references and named
arguments a bit hairy. For example, the following calls from a
template are undistinguishable for a plugin:

  [% P.some_func({ arg1 => 42, arg2 => 'Charlie' }) %]
  [% P.some_func(arg1 => 42, arg2 => 'Charlie') %]
  [% P.some_func(arg1=42, arg2='Charlie') %]
  [% P.some_func(arg1=42, arg2='Charlie') %]

C<AUTOLOAD> tries to be clever and unpacks a hash reference into a
normal hash if and only if it is the very last parameter to the
function call.

Returns the result of the corresponding function in the presenter.

=item C<escape $text>

Returns an HTML-escaped version of C<$text>. Instead of a string an
instance of the thin proxy-object L<SL::Presenter::EscapedText> is
returned.

It is safe to call C<escape> on an instance of
L<SL::Presenter::EscapedText>. This is a no-op (the same instance will
be returned).

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
