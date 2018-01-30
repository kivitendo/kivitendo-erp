package SL::PriceSource::Base;

use strict;

use parent qw(SL::DB::Object);
use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(record_item record fast) ],
);

sub name { die 'name needs to be implemented' }

sub description { die 'description needs to be implemented' }

sub available_prices { die 'available_prices needs to be implemented' }

sub available_discounts { die 'available_discounts needs to be implemented' }

sub best_price { die 'best_price needs to be implemented' }

sub best_discounts { die 'best_discounts needs to be implemented' }

sub price_from_source { die 'price_from_source needs to be implemented:' . "@_" }

sub discount_from_source { die 'discount_from_source needs to be implemented:' . "@_" }

sub part {
  $_[0]->record_item->part;
}

sub customer_vendor {
  $_[0]->record->is_sales ? $_[0]->record->customer : $_[0]->record->vendor;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::PriceSource::Base - this is the base class for price source adapters

=head1 SYNOPSIS

  # working example adapter:
  package SL::PriceSource::FiveOnEverything;

  use parent qw(SL::PriceSource::Base);

  # used as internal identifier
  sub name { 'simple' }

  # used in frontend to signal where this comes from
  sub description { t8('Simple') }

  my $price = SL::PriceSource::Price->new(
    price        => 5,
    description  => t8('Only today 5$ on everything!'),
    price_source => $self,
  );

  # give list of prices that this
  sub available_prices {
    return ($price);
  }

  sub best_price {
    return $price;
  }

  sub price_from_source {
    return $price;
  }

=head1 DESCRIPTION

See L<SL::PriceSource> for information about the mechanism.

This is the base class for a price source algorithm. To play well, you'll have
to implement a number of interface methods and be aware of a number of corner
conditions.

=head1 AVAILABLE METHODS

=over 4

=item C<record_item>

=item C<record>

C<record> can be any one of L<SL::DB::Order>, L<SL::DB::DeliveryOrder>,
L<SL::DB::Invoice>, L<SL::DB::PurchaseInvoice>. C<record_item> is of the
corresponding position type.

You can assume that both are filled with all information available at the time.
C<part> and C<customer>/C<vendor> as well as C<is_sales> can be relied upon. You must NOT
rely on both being linked together, in particular

  $self->record_item->record   # don't do that

is not guaranteed to work.

Also these are copies and not the original documents. Do not try to change
anything and do not save those.

=item C<part>

Shortcut to C<< record_item->part >>

=item C<customer_vendor>

Shortcut to C<< record->is_sales ? record->customer : record->vendor >>

=back

=head1 INTERFACE METHODS

=over 4

=item C<name>

Must return a unique internal name. Must be entered in
L<SL::PriceSource::ALL>.

=item C<description>

Must return a translated name to be used in the frontend. Will be used to
distinguish the origin of different prices.

=item C<available_prices>

Must return a list of all prices that your algorithm can recommend to the user
for the current situation. Each price must have a unique spec that can be used
to recreate it later. Try to be brief, no one needs 20 different price
suggestions.

=item C<available_discounts>

Must return a list of all prices that your algorithm can recommend to the user
for the current situation. Each discount must have a unique spec that can be
used to recreate it later. Try to be brief, no one needs 20 different discount
suggestions.

=item C<best_price>

Must return what you think of as the best matching price in your
C<available_prices>. This does not have to be the lowest price, but it will be
compared later to other price sources, and the lowest will be set.

=item C<best_discount>

Must return what you think of as the best matching discount in your
C<available_discounts>. This does not have to be the highest discount, but it
will be compared later to other price sources, and the highest will be set.

=item C<price_from_source SOURCE, SPEC>

Must recreate the price or discount from C<SPEC> and return. For reference, the
complete C<SOURCE> entry from C<record_item.active_price_source> or
C<record_item.active_discount_source> is included.

Note that constraints from the rest of the C<record> do not apply anymore. If
information needed for the retrieval can be deleted elsewhere, then you must
guard against that.

If the price for the same conditions changed, return the new price. It will be
presented as an option to the user if the record is still editable.

If the price is not valid anymore or not reconstructable, return a price with
C<price_source> and C<spec> set to the same values as before but with
C<invalid> or C<missing> set.

=back

=head1 TRAPS AND CORNER CASES

=over 4

=item *

Be aware that all 8 types of record will be passed to your algorithm. If you
don't serve some of them, just return empty lists on C<available_prices> and
C<best_price>

=item *

Information in C<record> might be missing. Especially on newly or automatically
created records there might be fields not set at all.

=item *

Records will not be calculated. If you need tax data or position totals, you
need to invoke that yourself.

=item *

Accessor methods might not be present in some of the record types.

=item *

You do not need to do price factor and row discount calculation. These will be
done automatically afterwards. You do have to include customer/vendor discounts
if your price interacts with those.

=item *

The price field in purchase records is still C<sellprice>.

=item *

C<source> and C<spec> are tainted. If you store data directly in C<spec>, sanitize.

=back

=head1 SEE ALSO

L<SL::PriceSource>,
L<SL::PriceSource::Price>,
L<SL::PriceSource::ALL>

=head1 BUGS

None yet. :)

=head1 AUTHOR

Sven Schoeling E<lt>s.schoeling@linet-services.deE<gt>

=cut
