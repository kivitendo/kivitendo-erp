use Test::More;

use strict;

use lib 't';

use Support::TestSetup;

use SL::DB::Tax;

use SL::Dev::ALL qw(:ALL);

Support::TestSetup::login();

####
# sales
####
my $invoice = create_sales_invoice();

my @expected_tax_ids = map {
  my $taxkey = $_->part->get_taxkey(date       => $invoice->effective_tax_point,
                                    is_sales   => $invoice->is_sales,
                                    taxzone_id => $invoice->taxzone_id);
  $taxkey->tax_id;
} @{$invoice->items_sorted};

my @tax_ids = map { $_->tax_id } @{$invoice->items_sorted};

is_deeply(\@tax_ids, \@expected_tax_ids, 'sales: tax_ids set by hook are ok');


####
# overwrite default taxes
####

# overwrite default tax for item 0
my $new_tax0 = SL::DB::Manager::Tax->get_first(where => ['!id' => $invoice->items_sorted->[0]->tax_id]);
$invoice->items_sorted->[0]->tax_id($new_tax0->id);

# set zero tax (id == 0) for item 1
$invoice->items_sorted->[1]->tax_id(0);

$_->save for @{$invoice->items_sorted};
# or $invoice->save(cascade => 1);

# force reloading from db
$invoice = SL::DB::Invoice->new(id => $invoice->id)->load;

@expected_tax_ids = ($new_tax0->id, 0);
@tax_ids          = map { $_->tax_id } @{$invoice->items_sorted};

is_deeply(\@tax_ids, \@expected_tax_ids, 'sales: preset tax_ids are ok');

####
# unset tax
####
$invoice->items_sorted->[0]->tax_id(undef);

$invoice->items_sorted->[0]->save;

# force reloading from db
$invoice = SL::DB::Invoice->new(id => $invoice->id)->load;

my $taxkey = $invoice->items_sorted->[0]->part->get_taxkey(date       => $invoice->effective_tax_point,
                                                           is_sales   => $invoice->is_sales,
                                                           taxzone_id => $invoice->taxzone_id);
my $expected_tax_id0 = $taxkey->tax_id;

@expected_tax_ids = ($expected_tax_id0, 0);
@tax_ids          = map { $_->tax_id } @{$invoice->items_sorted};

is_deeply(\@tax_ids, \@expected_tax_ids, 'sales: undef tax_ids is set to default');


####
# purchase
####
my $purchase_invoice = create_minimal_purchase_invoice(invnumber => 'pi1');

@expected_tax_ids = map {
  my $taxkey = $_->part->get_taxkey(date       => $purchase_invoice->effective_tax_point,
                                    is_sales   => $purchase_invoice->is_sales,
                                    taxzone_id => $purchase_invoice->taxzone_id);
  $taxkey->tax_id;
} @{$purchase_invoice->items_sorted};

@tax_ids = map { $_->tax_id } @{$purchase_invoice->items_sorted};

is_deeply(\@tax_ids, \@expected_tax_ids, 'purchase: tax_ids set by hook are ok');


####
# clear up
####
$invoice->delete(cascade => 1);
$purchase_invoice->delete(cascade => 1);
SL::DB::Manager::Part->delete_all(all => 1);

####
done_testing;

1;


# set emacs to perl mode
# Local Variables:
# mode: perl
# End:
