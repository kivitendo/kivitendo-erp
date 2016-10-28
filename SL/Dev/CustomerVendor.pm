package SL::Dev::CustomerVendor;

use strict;
use base qw(Exporter);
our @EXPORT = qw(create_customer);

use SL::DB::TaxZone;
use SL::DB::Currency;
use SL::DB::Customer;

sub create_customer {
  my (%params) = @_;

  my ($taxzone, $currency);

  if ( my $taxzone_id = delete $params{taxzone_id} ) {
    $taxzone = SL::DB::Manager::TaxZone->find_by( id => $taxzone_id ) || die "Can't find taxzone_id";
  } else {
    $taxzone = SL::DB::Manager::TaxZone->find_by( description => 'Inland') || die "No taxzone 'Inland'";
  }

  if ( my $currency_id = delete $params{currency_id} ) {
    $currency = SL::DB::Manager::Currency->find_by( id => $currency_id ) || die "Can't find currency_id";
  } else {
    $currency = SL::DB::Manager::Currency->find_by( id => $::instance_conf->get_currency_id );
  }

  my $customer = SL::DB::Customer->new( name        => delete $params{name} || 'Testkunde',
                                        currency_id => $currency->id,
                                        taxzone_id  => $taxzone->id,
                                      );
  $customer->assign_attributes( %params );
  return $customer;
}

1;

__END__

=head1 NAME

SL::Dev::CustomerVendor - create customer and vendor objects for testing, with minimal defaults

=head1 FUNCTIONS

=head2 C<create_customer %PARAMS>

Creates a new customer.

Minimal usage, default values, without saving to database:

  my $customer = SL::Dev::CustomerVendor::create_customer();

Complex usage, overwriting some defaults, and save to database:
  SL::Dev::CustomerVendor::create_customer(name        => 'Test customer',
                                           hourly_rate => 50,
                                           taxzone_id  => 2,
                                          )->save;


=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
1;
