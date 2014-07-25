package SL::PriceSource;

use strict;
use parent 'SL::DB::Object';
use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(record_item) ],
);

use List::UtilsBy qw(min_by);
use SL::PriceSource::ALL;
use SL::PriceSource::Price;
use SL::Locale::String;

sub all_price_sources {
  my ($self) = @_;

  return map {
    $_->new(record_item => $self->record_item)
  } SL::PriceSource::ALL->all_price_sources
}

sub price_from_source {
  my ($self, $source) = @_;
  my ($source_name, $spec) = split m{/}, $source, 2;

  my $class = SL::PriceSource::ALL->price_source_class_by_name($source_name);

  return $class
    ? $class->new(record_item => $self->record_item)->price_from_source($source, $spec)
    : empty_price();
}

sub available_prices {
  map { $_->available_prices } $_[0]->all_price_sources;
}

sub best_price {
  min_by { $_->price } map { $_->best_price } $_[0]->all_price_sources;
}

sub empty_price {
  SL::PriceSource::Price->new(
    source      => '',
    description => t8('None (PriceSource)'),
  );
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::PriceSource - mixin for price_sources in record items

=head1 SYNOPSIS

  # in record item class

  use SL::PriceSource;

  # later on:

  $record_item->all_price_sources
  $record_item->price_source      # get
  $record_item->price_source($c)  # set

  $record_item->update_price_source # set price to calculated

=head1 DESCRIPTION

This mixin provides a way to use price_source objects from within a record item.
Record items in this contest mean OrderItems, InvoiceItems and
DeliveryOrderItems.

=head1 FUNCTIONS

price_sources

returns a list of price_source objects which are created with the current record
item.

active_price_source

returns the object representing the currently chosen price_source method or
undef if custom price is chosen. Note that this must not necessarily be the
active price, if something affecting the price_source has changed, the price
calculated can differ from the price in the record. It is the responsibility of
the implementing code to decide what to do in this case.

=head1 BUGS

None yet. :)

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
