package SL::Dev::CustomerVendor;

use strict;
use base qw(Exporter);
our @EXPORT_OK = qw(new_customer new_vendor);
our %EXPORT_TAGS = (ALL => \@EXPORT_OK);

use SL::DB::TaxZone;
use SL::DB::Currency;
use SL::DB::Customer;

sub new_customer {
  my (%params) = @_;

  my $taxzone    = _check_taxzone(delete $params{taxzone_id});
  my $currency   = _check_currency(delete $params{currency_id});

  my $customer = SL::DB::Customer->new( name        => delete $params{name} || 'Testkunde',
                                        currency_id => $currency->id,
                                        taxzone_id  => $taxzone->id,
                                      );
  $customer->assign_attributes( %params );
  return $customer;
}

sub new_vendor {
  my (%params) = @_;

  my $taxzone    = _check_taxzone(delete $params{taxzone_id});
  my $currency   = _check_currency(delete $params{currency_id});

  my $vendor = SL::DB::Vendor->new( name        => delete $params{name} || 'Testlieferant',
                                    currency_id => $currency->id,
                                    taxzone_id  => $taxzone->id,
                                  );
  $vendor->assign_attributes( %params );
  return $vendor;
}

sub _check_taxzone {
  my ($taxzone_id) = @_;
  # check that taxzone_id exists or if no taxzone_id passed use 'Inland'
  my $taxzone;
  if ( $taxzone_id ) {
    $taxzone = SL::DB::Manager::TaxZone->find_by( id => $taxzone_id ) || die "Can't find taxzone_id";
  } else {
    $taxzone = SL::DB::Manager::TaxZone->find_by( description => 'Inland') || die "No taxzone 'Inland'";
  }
  return $taxzone;
}

sub _check_currency {
  my ($currency_id) = @_;
  my $currency;
  if ( $currency_id ) {
    $currency = SL::DB::Manager::Currency->find_by( id => $currency_id ) || die "Can't find currency_id";
  } else {
    $currency = SL::DB::Manager::Currency->find_by( id => $::instance_conf->get_currency_id );
  }
  return $currency;
}

1;

__END__

=head1 NAME

SL::Dev::CustomerVendor - create customer and vendor objects for testing, with minimal defaults

=head1 FUNCTIONS

=head2 C<new_customer %PARAMS>

Creates a new customer.

Minimal usage, default values, without saving to database:

  my $customer = SL::Dev::CustomerVendor::new_customer();

Complex usage, overwriting some defaults, and save to database:

  SL::Dev::CustomerVendor::new_customer(name        => 'Test customer',
                                           hourly_rate => 50,
                                           taxzone_id  => 2,
                                          )->save;

If neither taxzone_id or currency_id (both are NOT NULL) are passed as params
then default values are used.

=head2 C<new_vendor %PARAMS>

Creates a new vendor.

Minimal usage, default values, without saving to database:

  my $vendor = SL::Dev::CustomerVendor::create_vendor();

Complex usage, overwriting some defaults, and save to database:

  SL::Dev::CustomerVendor::create_vendor(name        => 'Test vendor',
                                         taxzone_id  => 2,
                                         notes       => "Order for 100$ for free delivery",
                                         payment_id  => 5,
                                        )->save;

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

G. Richardson E<lt>grichardson@kivitendo-premium.deE<gt>

=cut
