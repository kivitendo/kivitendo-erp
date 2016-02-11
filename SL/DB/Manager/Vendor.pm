package SL::DB::Manager::Vendor;

use strict;

use SL::DB::Helper::Manager;
use SL::DB::Helper::Sorted;
use SL::DB::Helper::Paginated;
use SL::DB::Helper::Filtered;
use base qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::Vendor' }

__PACKAGE__->make_manager_methods;

__PACKAGE__->add_filter_specs(
  all => sub {
    my ($key, $value, $prefix) = @_;
    return or => [ map { $prefix . $_ => $value } qw(vendornumber name) ]
  }
);

sub _sort_spec {
  return (
    default => [ 'name', 1 ],
    columns => {
      SIMPLE => 'ALL',
      map { ( $_ => "lower(vendor.$_)" ) } qw(account_number bank bank_code bcc bic cc city contact country department_1 department_2 depositor email fax gln greeting homepage iban language
                                              name notes phone street taxnumber user_password username ustid v_customer_id vendornumber zipcode)
    });
}
1;
