package SL::DB::Manager::Reclamation;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;
use SL::DB::Helper::Filtered;

sub object_class { 'SL::DB::Reclamation' }

__PACKAGE__->make_manager_methods;

__PACKAGE__->add_filter_specs(
  type => sub {
    my ($key, $value, $prefix) = @_;
    return __PACKAGE__->type_filter($value, $prefix);
  },
  # todo when is this used?
  #all => sub {
  #  my ($key, $value, $prefix) = @_;
  #  return or => [ map { $prefix . $_ => $value } qw(record_number customer.name vendor.name transaction_description) ]
  #}
);

sub type_filter {
  my $class  = shift;
  my $type   = lc(shift || '');
  my $prefix = shift || '';

  return (and => [ "!customer_id" => undef ]) if $type eq 'sales_reclamation';
  return (and => [ "!vendor_id"   => undef ]) if $type eq 'purchase_reclamation';

  die "Unknown type $type";
}

sub _sort_spec {
  return (
    default                   => [ 'transdate', 1 ],
    nulls                     => {
      transaction_description => 'FIRST',
      default                 => 'LAST',
    },
    columns                   => {
      SIMPLE                  => 'ALL',
      customer                => 'lower(customer.name)',
      vendor                  => 'lower(vendor.name)',
      employee                => 'lower(employee.name)',
      salesman                => 'lower(salesman.name)',
      contact                 => 'lower(contact.cp_name)',
      language                => 'lower(language.article_code)',
      department              => 'lower(department.description)',
      globalprojectnumber     => 'lower(globalproject.projectnumber)',
      delivery_term           => 'lower(delivery_term.description)',
      payment                 => 'lower(payment.description)',
      currency                => 'lower(currency.name)',
      taxzone                 => 'lower(taxzone.description)',

      # Bug in Rose::DB::Object: the next should be
      # "globalproject.project_type.description". This workaround will
      # only work if no other table with "project_type" is visible in
      # the current query
      globalproject_type      => 'lower(project_type.description)',

      map { ( $_ => "lower(reclamations.$_)" ) }
        qw(record_number cv_record_number shippingpoint shipvia notes intnotes
           transaction_description
        ),
    });
}

1;
