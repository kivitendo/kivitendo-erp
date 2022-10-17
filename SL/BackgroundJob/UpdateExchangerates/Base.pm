package SL::BackgroundJob::UpdateExchangerates::Base;

use strict;

use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(options) ],
);

sub update_rates {
  my ($self, $rates) = @_;
  die 'needs to be overwritten';
}

sub translate_currency_name {
  my ($self, $name) = @_;

  return $name if (!$self->options->{translate});
  return $self->options->{translate}->{$name} if $self->options->{translate}->{$name};
  return $name;
}


1;


__END__

=encoding utf-8

=head1 NAME

SL::BackgroundJob::UpdateExchangerates::Base - Base class for background job to update exchange rates.

=head1 SYNOPSIS

  # in update-worker:
  use parent qw(SL::BackgroundJob::UpdateExchangerates::Base);

  # implement interface
  sub update_rates {
    my ($self, $rates) = @_;

    foreach my $rate (@$rates) {
      my $from = $self->translate_currency_name($rate->{from}->name);
      my $to   = $self->translate_currency_name($rate->{to}->name);
      if ( $from eq 'EUR' && $to eq 'USD') {
        $rate->{rate} = 0.9205 if $rate->{dir} eq 'buy';
        $rate->{rate} = 0.9202 if $rate->{dir} eq 'sell';
      }
    }
  }

=head1 DESCRIPTION

This is a base class for a worker to update exchange rates.

=head1 INTERFACE

=over 4

=item C<update_rates $rates>

Your class will be instanciated and the update_rates method will be invoked.
This method can update known requeseted rates. Therefor an array of hashes with
information of the requested rates is provided. Each hash consists of the
following keys:

=over 5

=item

from: currency (instance of SL::DB::Currency) to be converted from

=item

to: currency (instance of SL::DB::Currency) to be converted to

=item

dir: 'bye' or 'sell'

=back

Your class should add a 'rate'-entry to each hash, if it can provide the rate
information. If not, it should leave the hash-entry as it is.

=back

=head1 FUNCTIONS

=over 4

=item C<translate_currency_name $name>

Returns the translated currency name, if a translation is given. This can be used to translate client specific
currency notations to the one used by the worker module. Translations are give as data to the background job:

options:
  translate:
    £: GBP

=back

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut

