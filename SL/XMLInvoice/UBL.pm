package SL::XMLInvoice::UBL;

use strict;
use warnings;

use parent qw(SL::XMLInvoice);

use constant ITEMS_XPATH => '//cac:InvoiceLine';

=head1 NAME

SL::XMLInvoice::UBL - XML parser for Universal Business Language invoices

=head1 DESCRIPTION

C<SL::XMLInvoice::UBL> parses XML invoices in Oasis Universal Business
Language format and makes their data available through the interface defined
by C<SL::XMLInvoice>. Refer to L<SL::XMLInvoice> for a detailed description of
that interface.

See L<http://docs.oasis-open.org/ubl/os-UBL-2.1/UBL-2.1.html#T-INVOICE> for
that format's specification.

=head1 OPERATION

This module is fairly simple. It keeps two hashes of XPath statements exposed
by methods:

=over 4

=item scalar_xpaths()

This hash is keyed by the keywords C<data_keys> mandates. Values are XPath
statements specifying the location of this field in the invoice XML document.

=item item_xpaths()

This hash is keyed by the keywords C<item_keys> mandates. Values are XPath
statements specifying the location of this field inside a line item.

=back

When invoked by the C<SL::XMLInvoice> constructor, C<parse_xml()> will first
use the XPath statements from the C<scalar_xpaths()> hash to populate the hash
returned by the C<metadata()> method.

After that, it will use the XPath statements from the C<scalar_xpaths()> hash
to iterate over the invoice's line items and populate the array of hashes
returned by the C<items()> method.

=head1 AUTHOR

  Johannes Grassler <info@computer-grassler.de>

=cut

# XML XPath expression for
sub scalar_xpaths {
  return {
    currency => '//cbc:DocumentCurrencyCode',
    direct_debit => '//cbc:PaymentMeansCode[@listID="UN/ECE 4461"]',
    duedate => '//cbc:DueDate',
    gross_total => '//cac:LegalMonetaryTotal/cbc:TaxInclusiveAmount',
    iban => '//cac:PayeeFinancialAccount/cbc:ID',
    invnumber => '//cbc:ID',
    net_total => '//cac:LegalMonetaryTotal/cbc:TaxExclusiveAmount',
    transdate => '//cbc:IssueDate',
    type => '//cbc:InvoiceTypeCode',
    taxnumber => '//cac:AccountingSupplierParty/cac:Party/cac:PartyTaxScheme/cbc:CompanyID',
    ustid => '//cac:AccountingSupplierParty/cac:Party/cac:PartyTaxScheme/cbc:CompanyID',
    vendor_name => '//cac:AccountingSupplierParty/cac:Party/cac:PartyName/cbc:Name',
  };
}

sub item_xpaths {
  return {
    'currency' => './cbc:LineExtensionAmount[attribute::currencyID]',
    'price' => './cac:Price/cbc:PriceAmount',
    'description' => './cac:Item/cbc:Description',
    'quantity' => './cbc:InvoicedQuantity',
    'subtotal' => './cbc:LineExtensionAmount',
    'tax_rate' => './/cac:ClassifiedTaxCategory/cbc:Percent',
    'tax_scheme' => './cac:Item/cac:ClassifiedTaxCategory/cac:TaxScheme/cbc:ID',
    'vendor_partno' => './cac:Item/cac:SellersItemIdentification/cbc:ID',
  };
}


# Metadata accessor method
sub metadata {
  my $self = shift;
  return $self->{_metadata};
}

# Item list accessor method
sub items {
  my $self = shift;
  return $self->{_items};
}

# Data keys we return
sub _data_keys {
  my $self = shift;
  my %keys;

  map { $keys{$_} = 1; } keys %{$self->scalar_xpaths};

  return \%keys;
}

# Item keys we return
sub _item_keys {
  my $self = shift;
  my %keys;

  map { $keys{$_} = 1; } keys %{$self->item_xpaths};

  return \%keys;
}

# Main parser subroutine for retrieving XML data
sub parse_xml {
  my $self = shift;
  $self->{_metadata} = {};
  $self->{_items} = ();

  # Retrieve scalar metadata from DOM
  foreach my $key ( keys %{$self->scalar_xpaths} ) {
    my $xpath = ${$self->scalar_xpaths}{$key};
    my $value = $self->{dom}->findnodes($xpath);
    if ( $value ) {
      # Get rid of extraneous white space
      $value = $value->string_value;
      $value =~ s/\n|\r//g;
      $value =~ s/\s{2,}/ /g;
      ${$self->{_metadata}}{$key} = $value;
    } else {
      ${$self->{_metadata}}{$key} = undef;
    }
  }

  # Convert payment code metadata field to Boolean
  # See https://service.unece.org/trade/untdid/d16b/tred/tred4461.htm for other valid codes.
  ${$self->{_metadata}}{'direct_debit'} = ${$self->{_metadata}}{'direct_debit'} == 59 ? 1 : 0;

  # UBL does not have a specified way of designating the tax scheme, so we'll
  # have to guess whether it's a tax ID or VAT ID (not using
  # SL::VATIDNr->validate here to keep this code portable):

  if ( ${$self->{_metadata}}{'ustid'} =~ qr"/" ) {
      # Unset this since the 'taxid' key has been retrieved with the same xpath
      # expression.
      ${$self->{_metadata}}{'ustid'} = undef;
  } else {
      # Unset this since the 'ustid' key has been retrieved with the same xpath
      # expression.
      ${$self->{_metadata}}{'taxnumber'} = undef;
  }

  my @items;
  $self->{_items} = \@items;

  foreach my $item ( $self->{dom}->findnodes(ITEMS_XPATH) ) {
    my %line_item;
    foreach my $key ( keys %{$self->item_xpaths} ) {
      my $xpath = ${$self->item_xpaths}{$key};
      my $value = $item->findnodes($xpath);
      if ( $value ) {
        # Get rid of extraneous white space
        $value = $value->string_value;
        $value =~ s/\n|\r//g;
        $value =~ s/\s{2,}/ /g;
        $line_item{$key} = $value;
      } else {
        $line_item{$key} = undef;
      }
    }
    push @items, \%line_item;
  }


}

1;
