package SL::XMLInvoice::CrossIndustryInvoice;

use strict;
use warnings;

use parent qw(SL::XMLInvoice::Base);

use constant ITEMS_XPATH => '//ram:IncludedSupplyChainTradeLineItem';

=head1 NAME

SL::XMLInvoice::CrossIndustryInvoice - XML parser for UN/CEFACT Cross Industry Invoice

=head1 DESCRIPTION

C<SL::XMLInvoice::CrossIndustryInvoice> parses XML invoices in UN/CEFACT Cross
Industry Invoice format and makes their data available through the interface
defined by C<SL::XMLInvoice>. Refer to L<SL::XMLInvoice> for a detailed
description of that interface.

See L<https://unece.org/trade/uncefact/xml-schemas> for that format's
specification.

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

sub supported {
  my @supported = ( "UN/CEFACT Cross Industry Invoice (urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100)" );
  return @supported;
}

sub check_signature {
  my ($self, $dom) = @_;

  my $rootnode = $dom->documentElement;

  foreach my $attr ( $rootnode->attributes ) {
    if ( $attr->getData =~ m/urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100/ ) {
      return 1;
      }
    }

  return 0;
}

# XML XPath expressions for global metadata
sub scalar_xpaths {
  return {
    currency => '//ram:InvoiceCurrencyCode',
    direct_debit => '//ram:SpecifiedTradeSettlementPaymentMeans/ram:TypeCode',
    duedate => '//ram:DueDateDateTime/udt:DateTimeString',
    gross_total => '//ram:DuePayableAmount',
    iban => '//ram:SpecifiedTradeSettlementPaymentMeans/ram:PayeePartyCreditorFinancialAccount/ram:IBANID',
    invnumber => '//rsm:ExchangedDocument/ram:ID',
    net_total => '//ram:SpecifiedTradeSettlementHeaderMonetarySummation' . '//ram:TaxBasisTotalAmount',
    transdate => '//ram:IssueDateTime/udt:DateTimeString',
    taxnumber => '//ram:SellerTradeParty/ram:SpecifiedTaxRegistration/ram:ID[@schemeID="FC"]',
    type => '//rsm:ExchangedDocument/ram:TypeCode',
    ustid => '//ram:SellerTradeParty/ram:SpecifiedTaxRegistration/ram:ID[@schemeID="VA"]',
    vendor_name => '//ram:SellerTradeParty/ram:Name',
  };
}

sub item_xpaths {
  return {
    'currency' => undef, # Only global currency in CrossIndustryInvoice
    'price' => './ram:SpecifiedLineTradeAgreement/ram:NetPriceProductTradePrice',
    'description' => './ram:SpecifiedTradeProduct/ram:Name',
    'quantity' => './ram:SpecifiedLineTradeDelivery/ram:BilledQuantity',
    'subtotal' => './ram:SpecifiedLineTradeSettlement/ram:SpecifiedTradeSettlementLineMonetarySummation/ram:LineTotalAmount',
    'tax_rate' => './ram:SpecifiedLineTradeSettlement/ram:ApplicableTradeTax/ram:RateApplicablePercent',
    'tax_scheme' => './ram:SpecifiedLineTradeSettlement/ram:ApplicableTradeTax/ram:TypeCode',
    'vendor_partno' => './ram:SpecifiedTradeProduct/ram:SellerAssignedID',
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

sub _xpath_context {
  my $xc = XML::LibXML::XPathContext->new;
  $xc->registerNs(udt => 'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100');
  $xc->registerNs(ram => 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100');
  $xc->registerNs(rsm => 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100');
  $xc;
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

  my $xc = _xpath_context();

  # Retrieve scalar metadata from DOM
  foreach my $key ( keys %{$self->scalar_xpaths} ) {
    my $xpath = ${$self->scalar_xpaths}{$key};
    unless ( $xpath ) {
      # Skip keys without xpath expression
      ${$self->{_metadata}}{$key} = undef;
      next;
    }
    my $value = $xc->find($xpath, $self->{dom});
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
  if (${$self->{_metadata}}{'direct_debit'}) {
    ${$self->{_metadata}}{'direct_debit'} = ${$self->{_metadata}}{'direct_debit'} == 59 ? 1 : 0;
  }

  my @items;
  $self->{_items} = \@items;

  foreach my $item ( $xc->findnodes(ITEMS_XPATH, $self->{dom}) ) {
    my %line_item;
    foreach my $key ( keys %{$self->item_xpaths} ) {
      my $xpath = ${$self->item_xpaths}{$key};
      unless ( $xpath ) {
        # Skip keys without xpath expression
        $line_item{$key} = undef;
        next;
      }
      my $value = $xc->find($xpath, $item);
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
