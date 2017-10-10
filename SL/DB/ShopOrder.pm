# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::ShopOrder;

use strict;

use SL::DBUtils;
use SL::DB::Shop;
use SL::DB::MetaSetup::ShopOrder;
use SL::DB::Manager::ShopOrder;
use SL::DB::Helper::LinkedRecords;
use SL::Locale::String qw(t8);
use Carp;

__PACKAGE__->meta->add_relationships(
  shop_order_items => {
    class      => 'SL::DB::ShopOrderItem',
    column_map => { id => 'shop_order_id' },
    type       => 'one to many',
  },
);

__PACKAGE__->meta->initialize;

sub convert_to_sales_order {
  my ($self, %params) = @_;

  my $customer = delete $params{customer};
  my $employee = delete $params{employee};
  croak "param customer is missing" unless ref($customer) eq 'SL::DB::Customer';
  croak "param employee is missing" unless ref($employee) eq 'SL::DB::Employee';

  require SL::DB::Order;
  require SL::DB::OrderItem;
  require SL::DB::Part;
  require SL::DB::Shipto;
  my @error_report;

  my @items = map{

    my $part = SL::DB::Manager::Part->find_by(partnumber => $_->partnumber);

    unless($part){
      push @error_report, t8('Part with partnumber: #1 not found', $_->partnumber);
    }else{
      my $current_order_item = SL::DB::OrderItem->new(
        parts_id            => $part->id,
        description         => $part->description,
        qty                 => $_->quantity,
        sellprice           => $_->price,
        unit                => $part->unit,
        position            => $_->position,
        active_price_source => $_->active_price_source,
      );
    }
  }@{ $self->shop_order_items };

  if(!scalar(@error_report)){

    my $shipto_id;
    if ($self->has_differing_delivery_address) {
      if(my $address = SL::DB::Manager::Shipto->find_by( shiptoname   => $self->delivery_fullname,
                                                         shiptostreet => $self->delivery_street,
                                                         shiptocity   => $self->delivery_city,
                                                        )) {
        $shipto_id = $address->{shipto_id};
      } else {
        my $deliveryaddress = SL::DB::Shipto->new;
        $deliveryaddress->assign_attributes(
          shiptoname         => $self->delivery_fullname,
          shiptodepartment_1 => $self->delivery_company,
          shiptodepartment_2 => $self->delivery_department,
          shiptostreet       => $self->delivery_street,
          shiptozipcode      => $self->delivery_zipcode,
          shiptocity         => $self->delivery_city,
          shiptocountry      => $self->delivery_country,
          trans_id           => $customer->id,
          module             => "CT",
        );
        $deliveryaddress->save;
        $shipto_id = $deliveryaddress->{shipto_id};
      }
    }

    my $shop = SL::DB::Manager::Shop->find_by(id => $self->shop_id);
    my $order = SL::DB::Order->new(
      amount                  => $self->amount,
      cusordnumber            => $self->shop_ordernumber,
      customer_id             => $customer->id,
      shipto_id               => $shipto_id,
      orderitems              => [ @items ],
      employee_id             => $employee->id,
      intnotes                => $customer->notes,
      salesman_id             => $employee->id,
      taxincluded             => $self->tax_included,
      payment_id              => $customer->payment_id,
      taxzone_id              => $customer->taxzone_id,
      currency_id             => $customer->currency_id,
      transaction_description => $shop->transaction_description,
      transdate               => DateTime->today_local
    );
     return $order;
   }else{
     my %error_order = (error   => 1,
                        errors  => [ @error_report ],
                       );
     return \%error_order;
   }
};

sub check_for_existing_customers {
  my ($self, %params) = @_;
  my $customers;

  my $name             = $self->billing_lastname ne '' ? $self->billing_firstname . " " . $self->billing_lastname : '';
  my $lastname         = $self->billing_lastname ne '' ? "%" . $self->billing_lastname . "%"                      : '';
  my $company          = $self->billing_company  ne '' ? "%" . $self->billing_company  . "%"                      : '';
  my $street           = $self->billing_street   ne '' ?  $self->billing_street                                   : '';
  my $street_not_fuzzy = $self->billing_street   ne '' ?  "%" . $self->billing_street . "%"                       : '';
  my $zipcode          = $self->billing_street   ne '' ?  $self->billing_zipcode                                  : '';
  my $email            = $self->billing_street   ne '' ?  $self->billing_email                                    : '';

  if($self->check_trgm) {
    # Fuzzysearch for street to find e.g. "Dorfstrasse - Dorfstr. - Dorfstraße"
    my $fs_query = <<SQL;
SELECT *
FROM customer
WHERE (
   (
    ( name ILIKE ? OR name ILIKE ? )
      AND
    zipcode ILIKE ?
   )
 OR
   ( street % ?  AND zipcode ILIKE ?)
 OR
   email ILIKE ?
) AND obsolete = 'F'
SQL

    my @values = ($lastname, $company, $self->billing_zipcode, $street, $self->billing_zipcode, $self->billing_email);

    $customers = SL::DB::Manager::Customer->get_objects_from_sql(
      sql  => $fs_query,
      args => \@values,
    );
  }else{
    # If trgm extension is not installed
    $customers = SL::DB::Manager::Customer->get_all(
      where => [
          or => [
            and => [
                     or => [ 'name' => { ilike => $lastname },
                             'name' => { ilike => $company  },
                           ],
                     'zipcode' => { ilike => $zipcode },
                   ],
            and => [
                     and => [ 'street'  => { ilike => $street_not_fuzzy },
                              'zipcode' => { ilike => $zipcode },
                            ],
                   ],
            or  => [ 'email' => { ilike => $email } ],
          ],
      ],
    );
  }

  return $customers;
}

sub get_customer{
  my ($self, %params) = @_;
  my $shop = SL::DB::Manager::Shop->find_by(id => $self->shop_id);
  my $customer_proposals = $self->check_for_existing_customers;
  my $name = $self->billing_firstname . " " . $self->billing_lastname;
  my $customer = 0;
  if(!scalar(@{$customer_proposals})){
    my %address = ( 'name'                  => $name,
                    'department_1'          => $self->billing_company,
                    'department_2'          => $self->billing_department,
                    'street'                => $self->billing_street,
                    'zipcode'               => $self->billing_zipcode,
                    'city'                  => $self->billing_city,
                    'email'                 => $self->billing_email,
                    'country'               => $self->billing_country,
                    'greeting'              => $self->billing_greeting,
                    'fax'                   => $self->billing_fax,
                    'phone'                 => $self->billing_phone,
                    'ustid'                 => $self->billing_vat,
                    'taxincluded_checked'   => $shop->pricetype eq "brutto" ? 1 : 0,
                    'taxincluded'           => $shop->pricetype eq "brutto" ? 1 : 0,
                    'pricegroup_id'         => (split '\/',$shop->price_source)[0] eq "pricegroup" ?  (split '\/',$shop->price_source)[1] : undef,
                    'taxzone_id'            => $shop->taxzone_id,
                    'currency'              => $::instance_conf->get_currency_id,
                    #'payment_id'            => 7345,# TODO hardcoded
                  );
    $customer = SL::DB::Customer->new(%address);

    $customer->save;
    my $snumbers = "customernumber_" . $customer->customernumber;
    SL::DB::History->new(
                      trans_id    => $customer->id,
                      snumbers    => $snumbers,
                      employee_id => SL::DB::Manager::Employee->current->id,
                      addition    => 'SAVED',
                      what_done   => 'Shopimport',
                    )->save();

  }elsif(scalar(@{$customer_proposals}) == 1){
    # check if the proposal is the right customer, could be different names under the same address. Depends on how first- and familyname is handled. Here is for customername = companyname or customername = "firstname familyname"
    $customer = SL::DB::Manager::Customer->find_by( id       => $customer_proposals->[0]->id,
                                                    name     => $name,
                                                    email    => $self->billing_email,
                                                    street   => $self->billing_street,
                                                    zipcode  => $self->billing_zipcode,
                                                    city     => $self->billing_city,
                                                    obsolete => 'F',
                                                  );
  }

  return $customer;
}

sub compare_to {
  my ($self, $other) = @_;

  return  1 if  $self->transfer_date && !$other->transfer_date;
  return -1 if !$self->transfer_date &&  $other->transfer_date;

  my $result = 0;
  $result    = $self->transfer_date <=> $other->transfer_date if $self->transfer_date;
  return $result || ($self->id <=> $other->id);
}

sub check_trgm {
  my ( $self ) = @_;

  my $dbh     = $::form->get_standard_dbh();
  my $sql     = "SELECT installed_version FROM pg_available_extensions WHERE name = 'pg_trgm'";
  my @version = selectall_hashref_query($::form, $dbh, $sql);

  return 1 if($version[0]->{installed_version});
  return 0;
}

sub has_differing_delivery_address {
  my ($self) = @_;
  ($self->billing_firstname // '') ne ($self->delivery_firstname // '') ||
  ($self->billing_lastname  // '') ne ($self->delivery_lastname  // '') ||
  ($self->billing_city      // '') ne ($self->delivery_city      // '') ||
  ($self->billing_street    // '') ne ($self->delivery_street    // '')
}

sub delivery_fullname {
  ($_[0]->delivery_firstname // '') . " " . ($_[0]->delivery_lastname // '')
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::DB::ShopOrder - Model for the 'shop_orders' table

=head1 SYNOPSIS

This is a standard Rose::DB::Object based model and can be used as one.

=head1 METHODS

=over 4

=item C<convert_to_sales_order>

=item C<check_for_existing_customers>

Inexact search for possible matches with existing customers in the database.

Returns all found customers as an arrayref of SL::DB::Customer objects.

=item C<get_customer>

returns only one customer from the check_for_existing_customers if the return from it is 0 or 1 customer.

When it is 0 get customer creates a new customer object of the shop order billing data and returns it

=item C<compare_to>

=item C<check_trgm>

Checks if the postgresextension pg_trgm is installed and return 0 or 1.

=back

=head1 TODO

some variables like payments could be better implemented. Transaction description is hardcoded

=head1 AUTHORS

Werner Hahn E<lt>wh@futureworldsearch.netE<gt>

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
