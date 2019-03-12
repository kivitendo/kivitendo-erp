package SL::DB::Manager::DeliveryOrder;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;
use SL::DB::Helper::Filtered;

sub object_class { 'SL::DB::DeliveryOrder' }

__PACKAGE__->make_manager_methods;

__PACKAGE__->add_filter_specs(
  type => sub {
    my ($key, $value, $prefix) = @_;
    return __PACKAGE__->type_filter($value, $prefix);
  },
  all => sub {
    my ($key, $value, $prefix) = @_;
    return or => [ map { $prefix . $_ => $value } qw(donumber customer.name vendor.name transaction_description orderitems.serialnumber) ]
  }
);

sub type_filter {
  my $class = shift;
  my $type  = lc(shift || '');

  return ('!customer_id' => undef) if $type eq 'sales_delivery_order';
  return ('!vendor_id'   => undef) if $type eq 'purchase_delivery_order';

  die "Unknown type $type";
}

sub _sort_spec {
  return (
    default                   => [ 'transdate', 1 ],
    nulls                     => {
      transaction_description => 'FIRST',
      customer_name           => 'FIRST',
      vendor_name             => 'FIRST',
      default                 => 'LAST',
    },
    columns                   => {
      SIMPLE                  => 'ALL',
      customer                => 'lower(customer.name)',
      vendor                  => 'lower(vendor.name)',
      globalprojectnumber     => 'lower(globalproject.projectnumber)',

      # Bug in Rose::DB::Object: the next should be
      # "globalproject.project_type.description". This workaround will
      # only work if no other table with "project_type" is visible in
      # the current query
      globalproject_type      => 'lower(project_type.description)',

      map { ( $_ => "lower(delivery_orders.$_)" ) } qw(donumber ordnumber cusordnumber oreqnumber shippingpoint shipvia notes intnotes transaction_description),
    });
}

sub default_objects_per_page { 40 }

1;
