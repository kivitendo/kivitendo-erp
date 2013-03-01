package SL::DB::Manager::PurchaseInvoice;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::PurchaseInvoice' }

__PACKAGE__->make_manager_methods;

sub type_filter {
  my $class = shift;
  my $type  = lc(shift || '');

  return (or  => [ invoice => 0, invoice => undef                       ]) if $type eq 'ap_transaction';
  return (and => [ invoice => 1, or => [ storno => 0, storno => undef ] ]) if $type =~ m/^(?:purchase_)?invoice$/;
  return (and => [ invoice => 1,         storno => 1                    ]) if $type =~ m/(?:invoice_)?storno/;

  die "Unknown type $type";
}

sub _sort_spec {
  return (
    default                   => [ 'transdate', 1 ],
    nulls                     => {
      transaction_description => 'FIRST',
      vendor_name             => 'FIRST',
      default                 => 'LAST',
    },
    columns                   => {
      SIMPLE                  => 'ALL',
      vendor                  => 'vendor.name',
      globalprojectnumber     => 'lower(globalproject.projectnumber)',

      # Bug in Rose::DB::Object: the next should be
      # "globalproject.project_type.description". This workaround will
      # only work if no other table with "project_type" is visible in
      # the current query
      globalproject_type      => 'lower(project_type.description)',

      map { ( $_ => "lower(ap.$_)" ) } qw(invnumber ordnumber quonumber shipvia notes intnotes transaction_description),
    });
}

sub default_objects_per_page { 40 }

1;
