package SL::PrefixedNumber;

use strict;

use parent qw(Rose::Object);

use Carp;
use List::Util qw(max);

use Rose::Object::MakeMethods::Generic
(
 scalar                  => [ qw(number) ],
 'scalar --get_set_init' => [ qw(_state) ],
);

sub init__state {
  my ($self) = @_;

  croak "No 'number' set" if !defined($self->number);

  my @matches    = $self->number =~ m/^(.*?)(\d+)$/;
  my @matches2   = $self->number =~ m/^(.*[^\d])$/;
  my $prefix     =  @matches2 ? $matches2[0] : (2 != scalar(@matches)) ? '' : $matches[ 0],;
  my $ref_number = !@matches  ? '0'          : $matches[-1];
  my $min_places = length $ref_number;

  return {
    prefix     => $prefix,
    ref_number => $ref_number,
    min_places => $min_places,
  };
}

sub get_current {
  my ($self) = @_;

  return $self->format($self->_state->{ref_number});
}

sub get_next {
  my ($self) = @_;

  return $self->set_to($self->_state->{ref_number} + 1);
}

sub format {
  my ($self, $number) = @_;

  my $state           = $self->_state;
  $number             =~ s/\.\d+//g;

  return $state->{prefix} . ('0' x max($state->{min_places} - length($number), 0)) . $number;
}

sub set_to {
  my ($self, $new_number) = @_;

  my $state            = $self->_state;
  $state->{ref_number} = $new_number;

  return $self->number($self->format($new_number));
}

sub set_to_max {
  my ($self, @numbers) = @_;

  return $self->set_to(max map { SL::PrefixedNumber->new(number => $_ // 0)->_state->{ref_number} } @numbers);
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::PrefixedNumber - Increment a number prefixed with some text

=head1 SYNOPSIS

  my $number = SL::PrefixedNumber->new(number => 'FB000042')->get_next;
  print $number; # FB000043

=head1 FUNCTIONS

=over 4

=item C<format $number>

Returns C<$number> formatted according to the rules in C<$self>. Does
not modify C<$self>. E.g.

  my $sequence = SL::PrefixedNumber->new('FB12345');
  print $sequence->format(42); # FB00042
  print $sequence->get_next;   # FB12346

=item C<get_current>

Returns the current number in the sequence (formatted). Does not
modify C<$self>.

=item C<get_next>

Returns the next number in the sequence (formatted). Modifies C<$self>
accordingly so that calling C<get_next> multiple times will actually
iterate over the sequence.

=item C<set_to $number>

Sets the current postfix to C<$number> but does not change the
prefix. Returns the formatted new number. E.g.:

  my $sequence = SL::PrefixedNumber->new(number => 'FB000042');
  print $sequence->set_to(123); # FB000123
  print $sequence->get_next;    # FB000124

=item C<set_to_max @numbers>

Sets the current postfix to the maximum of all the numbers listed in
C<@numbers>. All those numbers can be prefixed numbers. Returns the
formatted maximum number. E.g.

  my $sequence = SL::PrefixedNumber->new(number => 'FB000042');
  print $sequence->set_to_max('FB000123', 'FB999', 'FB00001'); # FB000999
  print $sequence->get_next;                                   # FB001000

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
