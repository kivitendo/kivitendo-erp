package SL::DB::Helper::IBANValidation;

use strict;

use Algorithm::CheckDigits ();
use Carp;
use SL::Locale::String qw(t8);

my $_validator;
my %_countries = (
  AT => { len => 20, name => t8('Austria') },
  BE => { len => 16, name => t8('Belgium') },
  CH => { len => 21, name => t8('Switzerland') },
  CZ => { len => 24, name => t8('Czech Republic') },
  DE => { len => 22, name => t8('Germany') },
  DK => { len => 18, name => t8('Denmark') },
  FR => { len => 27, name => t8('France') },
  IT => { len => 27, name => t8('Italy') },
  LU => { len => 20, name => t8('Luxembourg') },
  NL => { len => 18, name => t8('Netherlands') },
  PL => { len => 28, name => t8('Poland') },
);

sub _validate {
  my ($self, $attribute) = @_;

  my $iban =  $self->$attribute // '';
  $iban    =~ s{\s+}{}g;

  return () unless length($iban);

  $_validator //= Algorithm::CheckDigits::CheckDigits('iban');

  return ($::locale->text("The value '#1' is not a valid IBAN.", $iban)) if !$_validator->is_valid($iban);

  my $country = $_countries{substr($iban, 0, 2)};

  return () if !$country || (length($iban) == $country->{len});

  return ($::locale->text("The IBAN '#1' is not valid as IBANs in #2 must be exactly #3 characters long.", $iban, $country->{name}, $country->{len}));
}

sub import {
  my ($package, @attributes) = @_;

  my $caller_package         = caller;
  @attributes                = qw(iban) unless @attributes;

  no strict 'refs';

  *{ $caller_package . '::validate_ibans' } = sub {
    my ($self) = @_;

    return map { SL::DB::Helper::IBANValidation::_validate($self, $_) } @attributes;
  };
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::IBANValidation - Mixin for validating IBAN attributes

=head1 SYNOPSIS

  package SL::DB::SomeObject;
  use SL::DB::Helper::IBANValidation [ ATTRIBUTES ];

  sub validate {
    my ($self) = @_;

    my @errors;
    …
    push @errors, $self->validate_ibans;

    return @errors;
  }

This mixin provides a function C<validate_ibans> that returns a list
of error messages, one for each attribute that fails the IBAN
validation. If all attributes are valid or empty then an empty list
is returned.

The names of attributes to check can be given as an import list to the
mixin package. If no attributes are given the single attribute C<iban>
is used.

=head1 FUNCTIONS

=over 4

=item C<validate_ibans>

This function iterates over all configured attributes and validates
their content according to the IBAN standard. An attribute that is
undefined, empty or consists solely of whitespace is considered valid,
too.

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
