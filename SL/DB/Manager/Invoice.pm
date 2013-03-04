package SL::DB::Manager::Invoice;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Invoice' }

__PACKAGE__->make_manager_methods;

sub type_filter {
  my $class = shift;
  my $type  = lc(shift || '');

  return (or  => [ invoice => 0, invoice => undef                                               ]) if $type eq 'ar_transaction';
  return (and => [ invoice => 1, amount  => { ge => 0 }, or => [ storno => 0, storno => undef ] ]) if $type =~ m/^(?:sales_)?invoice$/;
  return (and => [ invoice => 1, amount  => { lt => 0 }, or => [ storno => 0, storno => undef ] ]) if $type eq 'credit_note';
  return (and => [ invoice => 1, amount  => { lt => 0 },         storno => 1                    ]) if $type =~ m/(?:invoice_)?storno/;
  return (and => [ invoice => 1, amount  => { ge => 0 },         storno => 1                    ]) if $type eq 'credit_note_storno';

  die "Unknown type $type";
}

sub _sort_spec {
  return (
    default                   => [ 'transdate', 1 ],
    nulls                     => {
      transaction_description => 'FIRST',
      customer_name           => 'FIRST',
      default                 => 'LAST',
    },
    columns                   => {
      SIMPLE                  => 'ALL',
      customer                => 'customer.name',
      globalprojectnumber     => 'lower(globalproject.projectnumber)',

      # Bug in Rose::DB::Object: the next should be
      # "globalproject.project_type.description". This workaround will
      # only work if no other table with "project_type" is visible in
      # the current query
      globalproject_type      => 'lower(project_type.description)',

      map { ( $_ => "lower(ar.$_)" ) } qw(invnumber ordnumber quonumber cusordnumber shippingpoint shipvia notes intnotes transaction_description),
    });
}

sub default_objects_per_page { 40 }

1;
