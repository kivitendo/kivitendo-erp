package SL::XMLInvoice::CrossIndustryDocument;

use strict;
use warnings;

use parent qw(SL::XMLInvoice::Base);

use constant ITEMS_XPATH => '//ram:IncludedSupplyChainTradeLineItem';
use constant TAX_TOTALS_XPATH => '//ram:ApplicableSupplyChainTradeSettlement/ram:ApplicableTradeTax';

=head1 NAME

SL::XMLInvoice::CrossIndustryDocument - XML parser for UN/CEFACT Cross Industry Document

=head1 DESCRIPTION

C<SL::XMLInvoice::CrossIndustryInvoice> parses XML invoices in UN/CEFACT Cross
Industry Document format (also known as ZUgFeRD 1p0 or ZUgFeRD 1.0)  and makes
their data available through the interface defined by C<SL::XMLInvoice>. Refer
to L<SL::XMLInvoice> for a detailed description of that interface.

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
  my @supported = ( "UN/CEFACT Cross Industry Document/ZUGFeRD 1.0 (urn:ferd:CrossIndustryDocument:invoice:1p0)" );
  return @supported;
}

sub check_signature {
  my ($self, $dom) = @_;

  my $rootnode = $dom->documentElement;

  foreach my $attr ( $rootnode->attributes ) {
    if ( $attr->getData =~ m/urn:ferd:CrossIndustryDocument:invoice:1p0/ ) {
      return 1;
      }
    }

  return 0;
}

# XML XPath expressions for global metadata
sub scalar_xpaths {
  return {
    currency => ['//ram:InvoiceCurrencyCode'],
    direct_debit => ['//ram:SpecifiedTradeSettlementPaymentMeans/ram:TypeCode'],
    duedate => ['//ram:DueDateDateTime/udt:DateTimeString', '//ram:EffectiveSpecifiedPeriod/ram:CompleteDateTime/udt:DateTimeString'],
    gross_total => ['//ram:DuePayableAmount'],
    iban => ['//ram:SpecifiedTradeSettlementPaymentMeans/ram:PayeePartyCreditorFinancialAccount/ram:IBANID'],
    invnumber => ['//rsm:HeaderExchangedDocument/ram:ID'],
    net_total => ['//ram:TaxBasisTotalAmount'],
    tax_total => ['//ram:TaxTotalAmount'],
    transdate => ['//ram:IssueDateTime/udt:DateTimeString'],
    taxnumber => ['//ram:SellerTradeParty/ram:SpecifiedTaxRegistration/ram:ID[@schemeID="FC"]'],
    type => ['//rsm:HeaderExchangedDocument/ram:TypeCode'],
    ustid => ['//ram:SellerTradeParty/ram:SpecifiedTaxRegistration/ram:ID[@schemeID="VA"]'],
    vendor_name => ['//ram:SellerTradeParty/ram:Name'],
  };
}

sub item_xpaths {
  return {
    'currency' => ['./ram:SpecifiedSupplyChainTradeAgreement/ram:GrossPriceProductTradePrice/ram:ChargeAmount[attribute::currencyID]',
                   './ram:SpecifiedSupplyChainTradeAgreement/ram:GrossPriceProductTradePrice/ram:BasisAmount'],
    'price' => ['./ram:SpecifiedSupplyChainTradeAgreement/ram:GrossPriceProductTradePrice/ram:ChargeAmount',
               './ram:SpecifiedSupplyChainTradeAgreement/ram:GrossPriceProductTradePrice/ram:BasisAmount'],
    'description' => ['./ram:SpecifiedTradeProduct/ram:Name'],
    'quantity' => ['./ram:SpecifiedSupplyChainTradeDelivery/ram:BilledQuantity',],
    'subtotal' => ['./ram:SpecifiedSupplyChainTradeSettlement/ram:SpecifiedTradeSettlementMonetarySummation/ram:LineTotalAmount'],
    'tax_rate' => ['./ram:SpecifiedSupplyChainTradeSettlement/ram:ApplicableTradeTax/ram:ApplicablePercent'],
    'tax_scheme' => ['./ram:SpecifiedSupplyChainTradeSettlement/ram:ApplicableTradeTax/ram:TypeCode'],
    'vendor_partno' => ['./ram:SpecifiedTradeProduct/ram:SellerAssignedID'],
  };
}

sub tax_totals_xpaths {
  return {
    'amount'        => './ram:CalculatedAmount',
    'type_code'     => './ram:TypeCode',
    'net_amount'    => './ram:BasisAmount',
    'category_code' => './ram:CategoryCode',
    'tax_rate'      => './ram:RateApplicablePercent',
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

# Taxes list accessor method
sub tax_totals {
  my $self = shift;
  return $self->{_taxes};
}

sub _xpath_context {
  my $xc = XML::LibXML::XPathContext->new;
  $xc->registerNs(udt => 'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:15');
  $xc->registerNs(ram => 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:12');
  $xc->registerNs(rsm => 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:1p0');
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
    foreach my $xpath ( @{${$self->scalar_xpaths}{$key}} ) {
      unless ( $xpath ) {
        # Skip keys without xpath list
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
        last; # first matching xpath wins
      } else {
        ${$self->{_metadata}}{$key} = undef;
      }
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
      foreach my $xpath ( @{${$self->item_xpaths}{$key}} ) {
        unless ( $xpath ) {
          # Skip keys without xpath list
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
          last; # first matching xpath wins
        } else {
          $line_item{$key} = undef;
        }
      }
    }

    # ZUGFeRD 1.0 doesn't really define what an item needs to have so it's possible to have purely informal items with only a note but without
    # name, qty or price. In ZUGFeRD 2.0 these are mandatory.
    #
    # To have any chance of parsing these in a business context, we filter out those that have _none_.

    next if !defined $line_item{description}
         && !defined $line_item{quantity}
         && !defined $line_item{subtotal};

    push @items, \%line_item;
  }

  my @taxes;
  $self->{_taxes} = \@taxes;

  foreach my $tax ( $xc->findnodes(TAX_TOTALS_XPATH, $self->{dom}) ) {
    my %tax_item;
    foreach my $key ( keys %{$self->tax_totals_xpaths} ) {
      my $xpath = ${$self->tax_totals_xpaths}{$key};
      unless ( $xpath ) {
        # Skip keys without xpath expression
        $tax_item{$key} = undef;
        next;
      }
      my $value = $xc->find($xpath, $tax);
      if ( $value ) {
        # Get rid of extraneous white space
        $value = $value->string_value;
        $value =~ s/\n|\r//g;
        $value =~ s/\s{2,}/ /g;
        $tax_item{$key} = $value;
      } else {
        $tax_item{$key} = undef;
      }
    }
    push @taxes, \%tax_item;
  }
}

1;
