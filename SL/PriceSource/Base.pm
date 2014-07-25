package SL::PriceSource::Base;

use strict;

use parent qw(SL::DB::Object);
use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(record_item record) ],
);

sub name { die 'name needs to be implemented' }

sub description { die 'description needs to be implemented' }

sub available_prices { die 'available_prices needs to be implemented' }

sub best_price { die 'best_price needs to be implemented' }

sub price_from_source { die 'price_from_source needs to be implemented:' . "@_" }

sub part {
  $_[0]->record_item->part;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::PriceSource::Base - <oneliner description>

=head1 SYNOPSIS

  # in consuming module
# TODO: thats bullshit, theres no need to have this pollute the namespace
# make a manager that handles this

  my @list_of_price_sources = $record_item->price_sources;
  for (@list_of_price_sources) {
    my $internal_name   = $_->name;
    my $translated_name = $_->description;
    my $price           = $_->price;
  }

  $record_item->set_active_price_source($price_source)  # equivalent to:
  $record_item->active_price_source($price_source->name);
  $record_item->sellprice($price_source->price);

  # for finer control
  $price_source->needed_params
  $price_source->supported_params

=head1 DESCRIPTION

PriceSource is an interface that allows generic algorithms to be used, to
calculate a price for a position in a record.

If any such price_source algorithm is known to the system, a user can chose
which of them should be used to claculate the price displayed in the record.

The algorithm is saved togetherwith the target price, so that changes in the
record can recalculate the price accordingly, and otherwise manual changes to
the price can reset the price_source used to custom (aka no price_source).

=head1 INTERFACE METHODS

=over 4

=item C<name>

Should return a unique internal name. Should be entered in
L<SL::PriceSource::ALL> so that a name_to_class lookup works.

=item C<description>

Should return a translated name.

=item C<needed_params>

Should return a list of elements that a record_item NEEDS to be used with this calulation.

Both C<needed_params> nad C<supported_params> are purely informational at this point.

=item C<supported_params>

Should return a list of elements that a record_item MAY HAVE to be used with this calulation.

Both C<needed_params> nad C<supported_params> are purely informational at this point.

=item C<price>

Calculate a price and return. Do not mutate the record_item. Should will return
undef if price is not applicable to the current record_item.

=back

=head1 BUGS

None yet. :)

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
