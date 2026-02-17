package SL::DB::Helper::ZUGFeRDValidator;

use strict;
use utf8;

use parent qw(Exporter);
our @EXPORT = qw(validate_zugferd_data);

use Carp;
use List::MoreUtils qw(any);
use List::Util qw(first);

use SL::Helper::ISO3166;
use SL::Helper::ISO4217;
use SL::Helper::UNECERecommendation20;
use SL::Locale::String qw(t8);
use SL::VATIDNr;
use SL::X;
use SL::ZUGFeRD qw(:PROFILES);

sub validate_zugferd_data {
  my ($self, %params) = @_;

  if ((ref($self) eq 'SL::DB::Order') && !$self->is_type(SL::DB::Order::SALES_ORDER_TYPE())) {
    croak "not implemented for SL::DB::Order types other than sales orders!";
  }

  my $is_sales_invoice  = ref($self) eq 'SL::DB::Invoice';
  my $is_sales_order    = ref($self) eq 'SL::DB::Order';  # execution for other Order types is prevented above

  my %result            = (valid => 1);
  my $prefix            = $params{prefix} // '';

  my %customer_settings = SL::ZUGFeRD->convert_customer_setting($self->customer->create_zugferd_invoices_for_this_customer);
  my $profile           = $customer_settings{profile};

  return %result if !defined($profile);

  if (!$::instance_conf->get_co_ustid) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('The VAT registration number is missing in the client configuration.'));
  }

  if (!SL::VATIDNr->validate($::instance_conf->get_co_ustid)) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . t8("The VAT ID number in the client configuration is invalid."));
  }

  if (!$::instance_conf->get_company || any { my $get = "get_address_$_"; !$::instance_conf->$get } qw(street1 zipcode city)) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('The company\'s address information is incomplete in the client configuration.'));
  }

  if ($::instance_conf->get_address_country && !SL::Helper::ISO3166::map_name_to_alpha_2_code($::instance_conf->get_address_country)) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('The country from the company\'s address in the client configuration cannot be mapped to an ISO 3166-1 alpha 2 code.'));
  }

  if (!$::instance_conf->get_invoice_mail) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('The company\'s invoice mail address is missing in the client configuration.'));
  }

  if ($self->customer->country && !SL::Helper::ISO3166::map_name_to_alpha_2_code($self->customer->country)) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('The country from the customer\'s address cannot be mapped to an ISO 3166-1 alpha 2 code.'));
  }

  if (!SL::Helper::ISO4217::map_currency_name_to_code($self->currency->name)) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('The currency "#1" cannot be mapped to an ISO 4217 currency code.', $self->currency->name));
  }

  my $failed_unit = first { !SL::Helper::UNECERecommendation20::map_name_to_code($_) } map { $_->unit } @{ $self->items };
  if ($failed_unit) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('One of the units used (#1) cannot be mapped to a known unit code from the UN/ECE Recommendation 20 list.', $failed_unit));
  }

  if ($is_sales_invoice && $self->direct_debit) {
    if (!$self->customer->iban) {
      SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('The customer\'s bank account number (IBAN) is missing.'));
    }

  } else {
    require SL::DB::Manager::BankAccount;
    my $bank_accounts     = SL::DB::Manager::BankAccount->get_all;
    $result{bank_account} = scalar(@{ $bank_accounts }) == 1 ? $bank_accounts->[0] : first { $_->use_for_zugferd } @{ $bank_accounts };

    if (!$result{bank_account}) {
      SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('No bank account flagged for Factur-X/ZUGFeRD usage was found.'));
    }
  }

  if ($is_sales_invoice && ($self->amount - $self->paid > 0)) {
    if (!$self->duedate && !$self->payment_terms) {
      SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('In case the amount due is positive, either due date or payment term must be set.'));
    }
  }

  if ($profile == PROFILE_XRECHNUNG()) {
    if (!$self->customer->c_vendor_routing_id) {
      SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('The value \'our routing id at customer\' must be set in the customer\'s master data for profile #1.', 'XRechnung 3.0'));
    }
  }

  #
  # GS1 GTIN/EAN/GLN/ILN and ISBN-13 all use the same check digits
  #
  my $v_ean = Algorithm::CheckDigits::CheckDigits('ean');
  if ($self->customer->gln && !$v_ean->is_valid($self->customer->gln)) {
      SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('Customer GLN check digit mismatch. #1 does not seem to be a valid GLN', $self->customer->gln));
  }

  if ($self->custom_shipto && $self->custom_shipto->shiptogln && !$v_ean->is_valid($self->custom_shipto->shiptogln)) {
    SL::X::ZUGFeRDValidation->throw(message => t8('Custom shipto GLN check digit mismatch. #1 does not seem to be a valid GLN', $self->custom_shipto->shiptogln));
  } elsif ($self->shipto && $self->shipto->shiptogln && !$v_ean->is_valid($self->shipto->shiptogln)) {
    SL::X::ZUGFeRDValidation->throw(message => t8('Shipto GLN check digit mismatch. #1 does not seem to be a valid GLN', $self->shipto->shiptogln));
  }

  if ($::instance_conf->get_gln && !$v_ean->is_valid($::instance_conf->get_gln)) {
      SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('Client config GLN check digit mismatch. #1 does not seem to be a valid GLN.', $::instance_conf->get_gln));
  }

  for my $item (@{ $self->items_sorted }) {
    if ($item->part->ean && !$v_ean->is_valid($item->part->ean)) {
        SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('EAN check digit mismatch for part #1. #2 does not seem to be a valid EAN.', $item->part->displayable_name, $item->part->ean));
    }
  }

  my $have_buyer_electronic_address = first { $self->customer->$_ } qw(invoice_mail email gln);
  if (!$have_buyer_electronic_address) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('At least one of the following fields has to be set in the customer data: Email of the invoice recipient; Email; GLN'));
  }

  if (($profile == PROFILE_XRECHNUNG()) && (($self->customer->c_vendor_routing_id // '') eq '')) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . t8('The routing ID has to be set in the customer data.'));
  }

  return %result;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Helper::ZUGFeRDValidator - validation of the configuration &
customer data needed for creating Factur-X/ZUGFeRD/XRechnung invoices

=head1 SYNOPSIS

Creating a Factur-X/ZUGFeRD/XRechnung invoice requires that several
pieces of information are available about both the seller (that's us)
and the recipient (that's our customers). Which data this is depends
on several factors:

=over 4

=item * the profile to create (XRechnung has more requirements than
Factur-X/ZUGFeRD)

=item * whether or not certain pieces of information are set in the
invoice

=item * the class & type this mixin is called on (supported are sales
invoices & sales orders, the former of which has more checks attached
to it)

=back

=head1 FUNCTIONS

=over 4

=item C<validate_zugferd_data> %params

Validates parameters, returns if validation was successful and throws
an exception of type C<SL::X::ZUGFeRDValidation> otherwise.

Optional parameters are:

=over 4

=item C<prefix> — optional prefix for the error messages contained in
thrown exceptions

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet.deE<gt>

=cut
