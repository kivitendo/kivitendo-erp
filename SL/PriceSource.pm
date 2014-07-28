package SL::PriceSource;

use strict;
use parent 'SL::DB::Object';
use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(record_item record) ],
);

use List::UtilsBy qw(min_by);
use SL::PriceSource::ALL;
use SL::PriceSource::Price;
use SL::Locale::String;

sub all_price_sources {
  my ($self) = @_;

  return map {
    $_->new(record_item => $self->record_item, record => $self->record)
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
    description => t8('None (PriceSource)'),
  );
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::PriceSource - mixin for price_sources in record items

=head1 DESCRIPTION

PriceSource is an interface that allows generic algorithms to be plugged
together to calculate available prices for a position in a record.

Each algorithm can access details of the record to realize dependancies on
part, customer, vendor, date, quantity etc, which was previously not possible.

=head1 BACKGROUND AND PHILOSOPY

sql ledger and subsequently Lx-Office had three prices per part: sellprice,
listprice and lastcost. At the moment a part is loaded into a record, the
applicable price is copied and after that free to be changed.

Later on additional things joined. Various types of discount, vendor pricelists
and the infamous price groups. The problem is not that those didn't work, the
problem is, that they had to guess to much when to change a price with the
available price from database, and when to leave the user entered price.

Unrelated to that, users asked for more ways to store special prices, based on
qty (block pricing, bulk discount), based on date (special offers), based on
customers (special terms), up to full blown calculation modules.

On a third front sales personnel asked for ways to see what price options a
position in a quotation has, and wanted information available when a price
offer changed.

Price sources put that together by making some compromises:

=over 4

=item 1.

Only change the price on creation of a position or when asked to.

=item 2.

Either set the price from a price source and let it be read only, or use a free
price.

=item 3.

Save the origin of each price with the record so that the calculation can be
reproduced.

=item 4.

Make price calculation flexible and pluggable.

=back

The first point creates user security by never changing a price for them
without their explicit consent, eliminating all problems originating from
trying to be smart. The second and third one ensure that later on the
calculation can be repeated so that invalid prices can be caught (because for
example the special offer is no longer valid), and so that sales personnel have
information about rising or falling prices. The fourth point ensures that
insular calculation processes can be developed independant of the core code.

=head1 INTERFACE METHODS

=over 4

=item C<new PARAMS>

C<PARAMS> must contain both C<record> and C<record_item>. C<record_item> does
not have to be registered in C<record>.

=item C<price_from_source>

Attempts to retrieve a formerly calculated price with the same conditions

=item C<available_prices>

Returns all available prices.

=item C<best_price>

Attempts to get the best available price. returns L<empty_price> if no price is found.

=item C<empty_price>

A special empty price, that does not change the previously entered price, and
opens the price field to manual changes.

=back

=head1 SEE ALSO

L<SL::PriceSource::Base>,
L<SL::PriceSource::Price>,
L<SL::PriceSource::ALL>

=head1 BUGS

None yet. :)

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
