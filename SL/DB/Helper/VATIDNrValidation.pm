package SL::DB::Helper::VATIDNrValidation;

use strict;

use Carp;
use SL::Locale::String qw(t8);
use SL::VATIDNr;

my $_validator;

sub _validate {
  my ($self, $attribute) = @_;

  my $number = SL::VATIDNr->clean($self->$attribute);

  return () unless length($number);
  return () if     SL::VATIDNr->validate($number);
  return ($::locale->text("The VAT ID number '#1' is invalid.", $self->$attribute));
}

sub import {
  my ($package, @attributes) = @_;

  my $caller_package         = caller;
  @attributes                = qw(ustid) unless @attributes;

  no strict 'refs';

  *{ $caller_package . '::validate_vat_id_numbers' } = sub {
    my ($self) = @_;

    return map { SL::DB::Helper::VATIDNrValidation::_validate($self, $_) } @attributes;
  };
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::VATIDNrValidation - Mixin for validating VAT ID number attributes

=head1 SYNOPSIS

  package SL::DB::SomeObject;
  use SL::DB::Helper::VATIDNrValidation [ ATTRIBUTES ];

  sub validate {
    my ($self) = @_;

    my @errors;
    …
    push @errors, $self->validate_vat_id_numbers;

    return @errors;
  }

This mixin provides a function C<validate_vat_id_numbers> that returns
a list of error messages, one for each attribute that fails the VAT ID
number validation. If all attributes are valid or empty then an empty
list is returned.

The names of attributes to check can be given as an import list to the
mixin package. If no attributes are given the single attribute C<ustid>
is used.

=head1 FUNCTIONS

=over 4

=item C<validate_vat_id_numbers>

This function iterates over all configured attributes and validates
their content according to how VAT ID numbers are supposed to be
formatted in the European Union (or the enterprise identification
numbers in Switzerland). An attribute that is undefined, empty or
consists solely of whitespace is considered valid, too.

The function returns a list of human-readable error messages suitable
for use in a general C<validate> function (see SYNOPSIS). For each
attribute failing the check the list will include one error message.

If all attributes are valid then an empty list is returned.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
