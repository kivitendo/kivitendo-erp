package SL::DB::Helper::ZUGFeRD;

use strict;
use utf8;

use parent qw(Exporter);
our @EXPORT_CREATE = qw(create_zugferd_data create_zugferd_xmp_data);
our @EXPORT_IMPORT = qw(import_zugferd_data);
our @EXPORT_OK = (@EXPORT_CREATE, @EXPORT_IMPORT);
our %EXPORT_TAGS     = (
  ALL => (@EXPORT_CREATE, @EXPORT_IMPORT),
  CREATE => \@EXPORT_CREATE,
  IMPORT => \@EXPORT_IMPORT,
);

use SL::Helper::ISO3166;
use SL::Helper::ISO4217;
use SL::Helper::UNECERecommendation20;
use SL::VATIDNr;
use SL::ZUGFeRD qw(:PROFILES);
use SL::Locale::String qw(t8);

use Algorithm::CheckDigits ();
use Carp;
use Encode qw(encode);
use List::MoreUtils qw(any pairwise);
use List::Util qw(first sum);
use Template;
use XML::Writer;
use Params::Validate qw(:all);

my @line_names = qw(LineOne LineTwo LineThree);

my %standards_ids = (
  PROFILE_FACTURX_EXTENDED() => 'urn:cen.eu:en16931:2017#conformant#urn:factur-x.eu:1p0:extended',
  PROFILE_XRECHNUNG()        => 'urn:cen.eu:en16931:2017#compliant#urn:xoev-de:kosit:standard:xrechnung_2.0',
);

sub _is_profile {
  my ($self, @profiles) = @_;
  return any { $self->{_zugferd}->{profile} == $_ } @profiles;
}

sub _u8 {
  my ($value) = @_;
  return encode('UTF-8', $value // '');
}

sub _r2 {
  my ($value) = @_;
  return $::form->round_amount($value, 2);
}

sub _type_name {
  my ($self) = @_;
  my $type   = $self->invoice_type;

  no warnings 'once';
  return $type eq 'ar_transaction' ? $::locale->text('Invoice') : $self->displayable_type;
}

sub _type_code {
  my ($self) = @_;
  my $type   = $self->invoice_type;

  # 326 (Partial invoice)
  # 380 (Commercial invoice)
  # 384 (Corrected Invoice)
  # 381 (Credit note)
  # 389 (Credit note, self billed invoice)

  return $type eq 'credit_note'        ? 381
       : $type eq 'invoice_storno'     ? 457
       : $type eq 'credit_note_storno' ? 458
       :                                 380;
}

sub _unit_code {
  my ($unit) = @_;

  # Mapping from kivitendo's units to UN/ECE Recommendation 20 & 21.
  my $code = SL::Helper::UNECERecommendation20::map_name_to_code($unit);
  return $code if $code;

  $::lxdebug->message(LXDebug::WARN(), "ZUGFeRD unit name mapping: no UN/ECE Recommendation 20/21 unit known for kivitendo unit '$unit'; using 'C62'");

  return 'C62';
}

sub _parse_our_address {
  my @result;
  my @street = grep { $_ } ($::instance_conf->get_address_street1, $::instance_conf->get_address_street2);

  push @result, [ 'PostcodeCode', $::instance_conf->get_address_zipcode ] if $::instance_conf->get_address_zipcode;
  push @result, grep { $_->[1] } pairwise { [ $a, $b] } @line_names, @street;
  push @result, [ 'CityName', $::instance_conf->get_address_city ] if $::instance_conf->get_address_city;
  push @result, [ 'CountryID', SL::Helper::ISO3166::map_name_to_alpha_2_code($::instance_conf->get_address_country) // 'DE' ];

  return @result;
}

sub _buyer_contact_information {
  my ($self, %params) = @_;

  my $contact = $params{contact};

  #       <ram:DefinedTradeContact>
  $params{xml}->startTag("ram:DefinedTradeContact");

  $params{xml}->dataElement("ram:PersonName", _u8(join(" ", $contact->cp_givenname, $contact->cp_name)));
  $params{xml}->dataElement("ram:DepartmentName", _u8($contact->cp_abteilung));

  my $phone_number = first {$_} (
    $contact->cp_phone1,
    $contact->cp_phone2,
    $contact->cp_mobile1,
    $contact->cp_mobile2,
    $contact->cp_satphone,
  );
  if ($phone_number) {
    $params{xml}->startTag("ram:TelephoneUniversalCommunication");
    $params{xml}->dataElement("ram:CompleteNumber", _u8($phone_number));
    $params{xml}->endTag;
  }

  if (_is_profile($self, PROFILE_FACTURX_EXTENDED())) {
    my $fax_number = first {$_} (
      $contact->cp_fax,
      $contact->cp_satfax,
    );
    if ($fax_number) {
      $params{xml}->startTag("ram:FaxUniversalCommunication");
      $params{xml}->dataElement("ram:CompleteNumber", _u8($fax_number));
      $params{xml}->endTag;
    }
  }

  if ($contact->cp_email) {
    $params{xml}->startTag("ram:EmailURIUniversalCommunication");
    $params{xml}->dataElement("ram:URIID", _u8($contact->cp_email));
    $params{xml}->endTag;
  }

  $params{xml}->endTag;
  #       </ram:DefinedTradeContact>
}

sub _customer_postal_trade_address {
  my (%params) = @_;

  #       <ram:PostalTradeAddress>
  $params{xml}->startTag("ram:PostalTradeAddress");

  my @parts = grep { $_ } map { $params{customer}->$_ } qw(department_1 department_2 street);

  $params{xml}->dataElement("ram:PostcodeCode", _u8($params{customer}->zipcode));
  $params{xml}->dataElement("ram:" . $_->[0],   _u8($_->[1])) for grep { $_->[1] } pairwise { [ $a, $b] } @line_names, @parts;
  $params{xml}->dataElement("ram:CityName",     _u8($params{customer}->city));
  $params{xml}->dataElement("ram:CountryID",    _u8(SL::Helper::ISO3166::map_name_to_alpha_2_code($params{customer}->country) // 'DE'));
  $params{xml}->endTag;
  #       </ram:PostalTradeAddress>
}

sub _buyer_communication {
  my (%params) = @_;
  my $customer = $params{customer};

  my $buyer_electronic_address = first {$_} (
    $customer->invoice_mail,
    $customer->email,
  );
  if ($buyer_electronic_address) {
    $params{xml}->startTag("ram:URIUniversalCommunication");
    $params{xml}->dataElement("ram:URIID", _u8($buyer_electronic_address), schemeID => 'EM');
    $params{xml}->endTag;
  } elsif ($customer->gln) {
    $params{xml}->startTag("ram:URIUniversalCommunication");
    $params{xml}->dataElement("ram:URIID", _u8($customer->gln), schemeID => '0088');
    $params{xml}->endTag;
  }
}

sub _tax_rate_and_code {
  my ($taxzone, $tax) = @_;

  my ($tax_rate, $tax_code) = @_;

  if ($taxzone->description =~ m{Au.*erhalb}) {
    $tax_rate = 0;
    $tax_code = 'G';

  } elsif ($taxzone->description =~ m{EU mit}) {
    $tax_rate = 0;
    $tax_code = 'K';

  } else {
    $tax_rate = $tax->rate * 100;
    $tax_code = !$tax_rate ? 'Z' : 'S';
  }

  return (rate => $tax_rate, code => $tax_code);
}

sub _line_item {
  my ($self, %params) = @_;

  my $item_ptc = $params{ptc_data}->{items}->[$params{line_number}];

  my $taxkey   = $item_ptc->{taxkey_id} ? SL::DB::TaxKey->load_cached($item_ptc->{taxkey_id}) : undef;
  my $tax      = $item_ptc->{taxkey_id} ? SL::DB::Tax->load_cached($taxkey->tax_id)           : undef;
  my %tax_info = _tax_rate_and_code($self->taxzone, $tax);

  # <ram:IncludedSupplyChainTradeLineItem>
  $params{xml}->startTag("ram:IncludedSupplyChainTradeLineItem");

  #   <ram:AssociatedDocumentLineDocument>
  $params{xml}->startTag("ram:AssociatedDocumentLineDocument");
  $params{xml}->dataElement("ram:LineID", $params{line_number} + 1);
  $params{xml}->endTag;

  $params{xml}->startTag("ram:SpecifiedTradeProduct");
  if ($params{item}->part->ean) {
    $params{xml}->dataElement("ram:SellerAssignedID", _u8($params{item}->part->ean), schemeID => '0160');
  } else {
    $params{xml}->dataElement("ram:SellerAssignedID", _u8($params{item}->part->partnumber));
  }
  $params{xml}->dataElement("ram:Name",             _u8($params{item}->description));
  $params{xml}->dataElement("ram:Description",      _u8($params{item}->longdescription_as_stripped_html))
    if $params{item}->longdescription_as_stripped_html;
  $params{xml}->endTag;

  $params{xml}->startTag("ram:SpecifiedLineTradeAgreement");
  $params{xml}->startTag("ram:GrossPriceProductTradePrice");
  $params{xml}->dataElement("ram:ChargeAmount", _r2($item_ptc->{sellprice}));
  $params{xml}->endTag;
  $params{xml}->startTag("ram:NetPriceProductTradePrice");
  $params{xml}->dataElement("ram:ChargeAmount", _r2($item_ptc->{sellprice}));
  $params{xml}->endTag;
  $params{xml}->endTag;
  #   </ram:SpecifiedLineTradeAgreement>

  #   <ram:SpecifiedLineTradeDelivery>
  $params{xml}->startTag("ram:SpecifiedLineTradeDelivery");
  $params{xml}->dataElement("ram:BilledQuantity", $params{item}->qty, unitCode => _unit_code($params{item}->unit));
  $params{xml}->endTag;
  #   </ram:SpecifiedLineTradeDelivery>

  #   <ram:SpecifiedLineTradeSettlement>
  $params{xml}->startTag("ram:SpecifiedLineTradeSettlement");

  #     <ram:ApplicableTradeTax>
  $params{xml}->startTag("ram:ApplicableTradeTax");
  $params{xml}->dataElement("ram:TypeCode",              "VAT");
  $params{xml}->dataElement("ram:CategoryCode",          $tax_info{code});
  $params{xml}->dataElement("ram:RateApplicablePercent", _r2($tax_info{rate}));
  $params{xml}->endTag;
  #     </ram:ApplicableTradeTax>

  #     <ram:SpecifiedTradeSettlementLineMonetarySummation>
  $params{xml}->startTag("ram:SpecifiedTradeSettlementLineMonetarySummation");
  $params{xml}->dataElement("ram:LineTotalAmount", _r2($item_ptc->{linetotal}));
  $params{xml}->endTag;
  #     </ram:SpecifiedTradeSettlementLineMonetarySummation>

  $params{xml}->endTag;
  #   </ram:SpecifiedLineTradeSettlement>

  $params{xml}->endTag;
  # <ram:IncludedSupplyChainTradeLineItem>
}

sub _specified_trade_settlement_payment_means {
  my ($self, %params) = @_;

  #     <ram:SpecifiedTradeSettlementPaymentMeans>
  $params{xml}->startTag('ram:SpecifiedTradeSettlementPaymentMeans');
  $params{xml}->dataElement('ram:TypeCode', $self->direct_debit ? 59 : 58); # 59 = SEPA direct debit, 58 = SEPA credit transfer

  if ($self->direct_debit) {
    $params{xml}->startTag('ram:PayerPartyDebtorFinancialAccount');
    $params{xml}->dataElement('ram:IBANID', $self->customer->iban);
    $params{xml}->endTag;

  } else {
    $params{xml}->startTag('ram:PayeePartyCreditorFinancialAccount');
    $params{xml}->dataElement('ram:IBANID', $params{bank_account}->iban);
    $params{xml}->endTag;
  }

  $params{xml}->endTag;
  #     </ram:SpecifiedTradeSettlementPaymentMeans>
}

sub _taxes {
  my ($self, %params) = @_;

  my %taxkey_info;

  foreach my $item (@{ $params{ptc_data}->{items} }) {
    $taxkey_info{$item->{taxkey_id}} //= {
      linetotal  => 0,
      tax_amount => 0,
    };
    my $info             = $taxkey_info{$item->{taxkey_id}};
    $info->{taxkey}    //= SL::DB::TaxKey->load_cached($item->{taxkey_id});
    $info->{tax}       //= SL::DB::Tax->load_cached($info->{taxkey}->tax_id);
    $info->{linetotal}  += $item->{linetotal};
  }

  foreach my $taxkey_id (sort keys %taxkey_info) {
    my $info     = $taxkey_info{$taxkey_id};
    my %tax_info = _tax_rate_and_code($self->taxzone, $info->{tax});

    #     <ram:ApplicableTradeTax>
    $params{xml}->startTag("ram:ApplicableTradeTax");
    $params{xml}->dataElement("ram:CalculatedAmount",      _r2($params{ptc_data}->{taxes_by_tax_id}->{$info->{taxkey}->tax_id}));
    $params{xml}->dataElement("ram:TypeCode",              "VAT");
    $params{xml}->dataElement("ram:BasisAmount",           _r2($info->{linetotal}));
    $params{xml}->dataElement("ram:CategoryCode",          $tax_info{code});
    $params{xml}->dataElement("ram:RateApplicablePercent", _r2($tax_info{rate}));
    $params{xml}->endTag;
    #     </ram:ApplicableTradeTax>
  }
}

sub _calculate_payment_terms_values {
  my ($self) = @_;

  my (%vars, %amounts, %formatted_amounts);

  local $::myconfig{numberformat} = $::myconfig{numberformat};
  local $::myconfig{dateformat}   = $::myconfig{dateformat};

  if ($self->language_id) {
    my $language = SL::DB::Language->load_cached($self->language_id);
    $::myconfig{dateformat}   = $language->output_dateformat   if $language->output_dateformat;
    $::myconfig{numberformat} = $language->output_numberformat if $language->output_numberformat;
  }

  $vars{currency}              = $self->currency->name if $self->currency;
  $vars{$_}                    = $self->customer->$_      for qw(account_number bank bank_code bic iban mandate_date_of_signature mandator_id);
  $vars{$_}                    = $self->payment_terms->$_ for qw(terms_netto terms_skonto percent_skonto);
  $vars{payment_description}   = $self->payment_terms->description;
  $vars{netto_date}            = $self->payment_terms->calc_date(reference_date => $self->transdate, due_date => $self->duedate, terms => 'net')->to_kivitendo;
  $vars{skonto_date}           = $self->payment_terms->calc_date(reference_date => $self->transdate, due_date => $self->duedate, terms => 'discount')->to_kivitendo;

  $amounts{invtotal}           = $self->amount;
  $amounts{total}              = $self->amount - $self->paid;

  $amounts{skonto_in_percent}  = 100.0 * $vars{percent_skonto};
  $amounts{skonto_amount}      = $amounts{invtotal} * $vars{percent_skonto};
  $amounts{invtotal_wo_skonto} = $amounts{invtotal} * (1 - $vars{percent_skonto});
  $amounts{total_wo_skonto}    = $amounts{total}    * (1 - $vars{percent_skonto});

  foreach (keys %amounts) {
    $amounts{$_}           = $::form->round_amount($amounts{$_}, 2);
    $formatted_amounts{$_} = $::form->format_amount(\%::myconfig, $amounts{$_}, 2);
  }

  return (
    vars              => \%vars,
    amounts           => \%amounts,
    formatted_amounts => \%formatted_amounts,
  );
}

sub _format_payment_terms_description {
  my ($self, %params) = @_;

  my $description = ($self->payment_terms->translated_attribute('description_long_invoice', $self->language_id) // '') || $self->payment_terms->description_long_invoice;
  $description    =~ s{<\%$_\%>}{ $params{vars}->{$_} }ge              for keys %{ $params{vars} };
  $description    =~ s{<\%$_\%>}{ $params{formatted_amounts}->{$_} }ge for keys %{ $params{formatted_amounts} };

  if (_is_profile($self, PROFILE_XRECHNUNG())) {
    my @terms;

    if ($self->payment_terms->terms_skonto && ($self->payment_terms->percent_skonto * 1)) {
      push @terms, sprintf("#SKONTO#TAGE=\%d#PROZENT=\%.2f#\n", $self->payment_terms->terms_skonto, $self->payment_terms->percent_skonto * 100);
    }

    $description =~ s{#}{_}g;
    $description =  join('', @terms) . $description;
  }

  return $description;
}

sub _payment_terms {
  my ($self, %params) = @_;

  return if !$self->payment_terms && !$self->duedate;

  if (!$self->payment_terms) { # only duedate
    #     <ram:SpecifiedTradePaymentTerms>
    $params{xml}->startTag("ram:SpecifiedTradePaymentTerms");

    #       <ram:DueDateDateTime>
    $params{xml}->startTag("ram:DueDateDateTime");
    $params{xml}->dataElement("udt:DateTimeString", $self->duedate->strftime('%Y%m%d'), format => "102");
    $params{xml}->endTag;
    #       </ram:DueDateDateTime>

    $params{xml}->endTag;
    #     </ram:SpecifiedTradePaymentTerms>
    return;
  }

  my %payment_terms_vars = _calculate_payment_terms_values($self);

  #     <ram:SpecifiedTradePaymentTerms>
  $params{xml}->startTag("ram:SpecifiedTradePaymentTerms");

  $params{xml}->dataElement("ram:Description", _u8(_format_payment_terms_description($self, %payment_terms_vars)));

  #       <ram:DueDateDateTime>
  $params{xml}->startTag("ram:DueDateDateTime");
  $params{xml}->dataElement("udt:DateTimeString", $self->duedate->strftime('%Y%m%d'), format => "102");
  $params{xml}->endTag;
  #       </ram:DueDateDateTime>

  if (   _is_profile($self, PROFILE_FACTURX_EXTENDED())
      && $self->payment_terms->percent_skonto
      && $self->payment_terms->terms_skonto) {
    my $currency_id = _u8(SL::Helper::ISO4217::map_currency_name_to_code($self->currency->name) // 'EUR');

    #       <ram:ApplicableTradePaymentDiscountTerms>
    $params{xml}->startTag("ram:ApplicableTradePaymentDiscountTerms");
    $params{xml}->dataElement("ram:BasisPeriodMeasure", $self->payment_terms->terms_skonto, unitCode => "DAY");
    $params{xml}->dataElement("ram:BasisAmount",        _r2($payment_terms_vars{amounts}->{invtotal}));
    $params{xml}->dataElement("ram:CalculationPercent", _r2($self->payment_terms->percent_skonto * 100));
    $params{xml}->endTag;
    #       </ram:ApplicableTradePaymentDiscountTerms>
  }

  $params{xml}->endTag;
  #     </ram:SpecifiedTradePaymentTerms>
}

sub _totals {
  my ($self, %params) = @_;

  #     <ram:SpecifiedTradeSettlementHeaderMonetarySummation>
  $params{xml}->startTag("ram:SpecifiedTradeSettlementHeaderMonetarySummation");

  $params{xml}->dataElement("ram:LineTotalAmount",     _r2($self->netamount));
  $params{xml}->dataElement("ram:TaxBasisTotalAmount", _r2($self->netamount));
  $params{xml}->dataElement("ram:TaxTotalAmount",      _r2(sum(values %{ $params{ptc_data}->{taxes_by_tax_id} })), currencyID => "EUR");
  $params{xml}->dataElement("ram:GrandTotalAmount",    _r2($self->amount));
  $params{xml}->dataElement("ram:TotalPrepaidAmount",  _r2($self->paid));
  $params{xml}->dataElement("ram:DuePayableAmount",    _r2($self->amount - $self->paid));

  $params{xml}->endTag;
  #     </ram:SpecifiedTradeSettlementHeaderMonetarySummation>
}

sub _exchanged_document_context {
  my ($self, %params) = @_;

  #   <rsm:ExchangedDocumentContext>
  $params{xml}->startTag("rsm:ExchangedDocumentContext");

  if ($self->{_zugferd}->{test_mode}) {
    $params{xml}->startTag("ram:TestIndicator");
    $params{xml}->dataElement("udt:Indicator", "true");
    $params{xml}->endTag;
  }

  $params{xml}->startTag("ram:GuidelineSpecifiedDocumentContextParameter");
  $params{xml}->dataElement("ram:ID", $standards_ids{ $self->{_zugferd}->{profile} });
  $params{xml}->endTag;
  $params{xml}->endTag;
  #   </rsm:ExchangedDocumentContext>
}

sub _included_note {
  my ($self, %params) = @_;

  $params{xml}->startTag("ram:IncludedNote");
  $params{xml}->dataElement("ram:Content", _u8($params{note}));
  $params{xml}->endTag;
}

sub _exchanged_document {
  my ($self, %params) = @_;

  #   <rsm:ExchangedDocument>
  $params{xml}->startTag("rsm:ExchangedDocument");

  $params{xml}->dataElement("ram:ID",       _u8($self->invnumber));
  $params{xml}->dataElement("ram:Name",     _u8(_type_name($self))) if _is_profile($self, PROFILE_FACTURX_EXTENDED());
  $params{xml}->dataElement("ram:TypeCode", _u8(_type_code($self)));

  #     <ram:IssueDateTime>
  $params{xml}->startTag("ram:IssueDateTime");
  $params{xml}->dataElement("udt:DateTimeString", $self->transdate->strftime('%Y%m%d'), format => "102");
  $params{xml}->endTag;
  #     </ram:IssueDateTime>

  if (   _is_profile($self, PROFILE_FACTURX_EXTENDED())
      && $self->language
      && (($self->language->template_code // '') =~ m{^(de|en)}i)) {
    $params{xml}->dataElement("ram:LanguageID", uc($1));
  }

  require SL::DB::GenericTranslation;
  my $std_notes = SL::DB::Manager::GenericTranslation->get_all(
    where => [
      translation_type => 'ZUGFeRD/notes',
      or               => [
        language_id    => undef,
        language_id    => $self->language_id,
      ],
      '!translation'   => undef,
      '!translation'   => '',
    ],
  );

  my $std_note = first { $_->language_id == $self->language_id } @{ $std_notes };
  $std_note  //= first { !defined $_->language_id }              @{ $std_notes };

  my $notes = $self->notes_as_stripped_html;

  _included_note($self, %params, note => $self->transaction_description) if $self->transaction_description;
  _included_note($self, %params, note => $notes)                         if $notes;
  _included_note($self, %params, note => $std_note->translation)         if $std_note;

  $params{xml}->endTag;
  #   </rsm:ExchangedDocument>
}

sub _specified_tax_registration {
  my ($ustid_nr, %params) = @_;

  #         <ram:SpecifiedTaxRegistration>
  $params{xml}->startTag("ram:SpecifiedTaxRegistration");
  $params{xml}->dataElement("ram:ID", _u8(SL::VATIDNr->normalize($ustid_nr)), schemeID => "VA");
  $params{xml}->endTag;
  #         </ram:SpecifiedTaxRegistration>
}

sub _seller_trade_party {
  my ($self, %params) = @_;

  my @our_address            = _parse_our_address();

  my $sales_person           = $self->salesman;
  my $sales_person_auth      = SL::DB::Manager::AuthUser->find_by(login => $sales_person->login);
  my %sales_person_cfg       = $sales_person_auth ? %{ $sales_person_auth->config_values } : ();
  $sales_person_cfg{email} ||= $sales_person->deleted_email;
  $sales_person_cfg{tel}   ||= $sales_person->deleted_tel;

  #       <ram:SellerTradeParty>
  $params{xml}->startTag("ram:SellerTradeParty");
  # 0088 = GLN, 0060 = D-U-N-S, only one ID is allowed
  if ($self->customer->c_vendor_id) {
    $params{xml}->dataElement("ram:ID", _u8($self->customer->c_vendor_id));
  } elsif($::instance_conf->get_gln) {
    $params{xml}->dataElement("ram:ID", _u8($::instance_conf->get_gln), schemeID => '0088');
  } elsif($::instance_conf->get_duns) {
    $params{xml}->dataElement("ram:ID", _u8($::instance_conf->get_duns), schemeID => '0060');
  } else {
    # no sensible default yet
  }
  $params{xml}->dataElement("ram:Name", _u8($::instance_conf->get_company));

  #         <ram:DefinedTradeContact>
  $params{xml}->startTag("ram:DefinedTradeContact");

  $params{xml}->dataElement("ram:PersonName", _u8($sales_person->safe_name));

  if ($sales_person_cfg{tel}) {
    $params{xml}->startTag("ram:TelephoneUniversalCommunication");
    $params{xml}->dataElement("ram:CompleteNumber", _u8($sales_person_cfg{tel}));
    $params{xml}->endTag;
  }

  if ($sales_person_cfg{email}) {
    $params{xml}->startTag("ram:EmailURIUniversalCommunication");
    $params{xml}->dataElement("ram:URIID", _u8($sales_person_cfg{email}));
    $params{xml}->endTag;
  }

  $params{xml}->endTag;
  #         </ram:DefinedTradeContact>

  if (@our_address) {
    #         <ram:PostalTradeAddress>
    $params{xml}->startTag("ram:PostalTradeAddress");
    foreach my $element (@our_address) {
      $params{xml}->dataElement("ram:" . $element->[0], _u8($element->[1]));
    }
    $params{xml}->endTag;
    #         </ram:PostalTradeAddress>
  }

  _specified_tax_registration($::instance_conf->get_co_ustid, %params);

  $params{xml}->endTag;
  #     </ram:SellerTradeParty>
}

sub _buyer_trade_party {
  my ($self, %params) = @_;

  #       <ram:BuyerTradeParty>
  $params{xml}->startTag("ram:BuyerTradeParty");
  if ($self->customer->gln) {
    $params{xml}->dataElement("ram:ID", _u8($self->customer->gln), schemeID => '0088');
  } else {
    $params{xml}->dataElement("ram:ID", _u8($self->customer->customernumber));
  }
  $params{xml}->dataElement("ram:Name", _u8($self->customer->name));

  _buyer_contact_information($self, %params, contact => $self->contact) if ($self->cp_id);
  _customer_postal_trade_address(%params, customer => $self->customer);
  _buyer_communication(%params, customer => $self->customer);
  _specified_tax_registration($self->customer->ustid, %params) if $self->customer->ustid;

  $params{xml}->endTag;
  #       </ram:BuyerTradeParty>
}

sub _included_supply_chain_trade_line_item {
  my ($self, %params) = @_;

  my $line_number = 0;
  foreach my $item (@{ $self->items }) {
    _line_item($self, %params, item => $item, line_number => $line_number);
    $line_number++;
  }
}

sub _applicable_header_trade_agreement {
  my ($self, %params) = @_;

  #     <ram:ApplicableHeaderTradeAgreement>
  $params{xml}->startTag("ram:ApplicableHeaderTradeAgreement");

  # BuyerReference must always be given in XRechnung v3.0.2 BT-10.
  # Factur-X doesn't really say anything about it and only has it as optional in the schema.
  # Technically this means that the Factur-X:conformant profile doesn't have to include it, but validators seem to be overzealous here.
  # To be on the safe side put a fallback in there for conformant profiles, but be strict about it in XRechnung compliant profiles.
  if ($standards_ids{ $self->{_zugferd}->{profile} } =~ /compliant/) {
    if (!defined $self->customer->c_vendor_routing_id) {
      die t8("Can not create an EN16931 compliant ZUGFeRD export without a routing id (Leitweg ID)");
    } else {
      $params{xml}->dataElement("ram:BuyerReference", _u8($self->customer->c_vendor_routing_id));
    }
  } else {
    my $buyer_reference = $self->customer->c_vendor_routing_id || $self->cusordnumber || $self->customer->ustid || '';
    $params{xml}->dataElement("ram:BuyerReference", _u8($buyer_reference));
  }

  _seller_trade_party($self, %params);
  _buyer_trade_party($self, %params);

  if ($self->cusordnumber) {
    #     <ram:BuyerOrderReferencedDocument>
    $params{xml}->startTag("ram:BuyerOrderReferencedDocument");
    $params{xml}->dataElement("ram:IssuerAssignedID", _u8($self->cusordnumber));
    $params{xml}->endTag;
    #     </ram:BuyerOrderReferencedDocument>
  }

  $params{xml}->endTag;
  #     </ram:ApplicableHeaderTradeAgreement>
}

sub _applicable_header_trade_delivery {
  my ($self, %params) = @_;

  #     <ram:ApplicableHeaderTradeDelivery>
  $params{xml}->startTag("ram:ApplicableHeaderTradeDelivery");
  #       <ram:ActualDeliverySupplyChainEvent>
  $params{xml}->startTag("ram:ActualDeliverySupplyChainEvent");

  $params{xml}->startTag("ram:OccurrenceDateTime");
  $params{xml}->dataElement("udt:DateTimeString", ($self->deliverydate // $self->transdate)->strftime('%Y%m%d'), format => "102");
  $params{xml}->endTag;

  $params{xml}->endTag;
  #       </ram:ActualDeliverySupplyChainEvent>
  $params{xml}->endTag;
  #     </ram:ApplicableHeaderTradeDelivery>
}

sub _applicable_header_trade_settlement {
  my ($self, %params) = @_;

  #     <ram:ApplicableHeaderTradeSettlement>
  $params{xml}->startTag("ram:ApplicableHeaderTradeSettlement");
  $params{xml}->dataElement("ram:InvoiceCurrencyCode", _u8(SL::Helper::ISO4217::map_currency_name_to_code($self->currency->name) // 'EUR'));

  _specified_trade_settlement_payment_means($self, %params);
  _taxes($self, %params);
  _payment_terms($self, %params);
  _totals($self, %params);

  $params{xml}->endTag;
  #     </ram:ApplicableHeaderTradeSettlement>
}

sub _supply_chain_trade_transaction {
  my ($self, %params) = @_;

  #   <rsm:SupplyChainTradeTransaction>
  $params{xml}->startTag("rsm:SupplyChainTradeTransaction");

  _included_supply_chain_trade_line_item($self, %params);
  _applicable_header_trade_agreement($self, %params);
  _applicable_header_trade_delivery($self, %params);
  _applicable_header_trade_settlement($self, %params);

  $params{xml}->endTag;
  #   </rsm:SupplyChainTradeTransaction>
}

sub _validate_data {
  my ($self) = @_;

  my %result;
  my $prefix = $::locale->text('The ZUGFeRD invoice data cannot be generated because the data validation failed.') . ' ';

  if (!$::instance_conf->get_co_ustid) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text('The VAT registration number is missing in the client configuration.'));
  }

  if (!SL::VATIDNr->validate($::instance_conf->get_co_ustid)) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text("The VAT ID number in the client configuration is invalid."));
  }

  if (!$::instance_conf->get_company || any { my $get = "get_address_$_"; !$::instance_conf->$get } qw(street1 zipcode city)) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text('The company\'s address information is incomplete in the client configuration.'));
  }

  if ($::instance_conf->get_address_country && !SL::Helper::ISO3166::map_name_to_alpha_2_code($::instance_conf->get_address_country)) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text('The country from the company\'s address in the client configuration cannot be mapped to an ISO 3166-1 alpha 2 code.'));
  }

  if ($self->customer->country && !SL::Helper::ISO3166::map_name_to_alpha_2_code($self->customer->country)) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text('The country from the customer\'s address cannot be mapped to an ISO 3166-1 alpha 2 code.'));
  }

  if (!SL::Helper::ISO4217::map_currency_name_to_code($self->currency->name)) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text('The currency "#1" cannot be mapped to an ISO 4217 currency code.', $self->currency->name));
  }

  my $failed_unit = first { !SL::Helper::UNECERecommendation20::map_name_to_code($_) } map { $_->unit } @{ $self->items };
  if ($failed_unit) {
    SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text('One of the units used (#1) cannot be mapped to a known unit code from the UN/ECE Recommendation 20 list.', $failed_unit));
  }

  if ($self->direct_debit) {
    if (!$self->customer->iban) {
      SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text('The customer\'s bank account number (IBAN) is missing.'));
    }

  } else {
    require SL::DB::Manager::BankAccount;
    my $bank_accounts     = SL::DB::Manager::BankAccount->get_all;
    $result{bank_account} = scalar(@{ $bank_accounts }) == 1 ? $bank_accounts->[0] : first { $_->use_for_zugferd } @{ $bank_accounts };

    if (!$result{bank_account}) {
      SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text('No bank account flagged for Factur-X/ZUGFeRD usage was found.'));
    }
  }

  if ($self->amount - $self->paid > 0) {
    if (!$self->duedate && !$self->payment_terms) {
      SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text('In case the amount due is positive, either due date or payment term must be set.'));
    }
  }

  if (_is_profile($self, PROFILE_XRECHNUNG())) {
    if (!$self->customer->c_vendor_routing_id) {
      SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text('The value \'our routing id at customer\' must be set in the customer\'s master data for profile #1.', 'XRechnung 2.0'));
    }
  }

  #
  # GS1 GTIN/EAN/GLN/ILN and ISBN-13 all use the same check digits
  #
  if ($self->customer->gln && !Algorithm::CheckDigits::CheckDigits('ean')->is_valid($self->customer->gln)) {
      SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text('Customer GLN check digit mismatch. #1 does not seem to be a valid GLN', $self->customer->gln));
  }

  if ($::instance_conf->get_gln && !Algorithm::CheckDigits::CheckDigits('ean')->is_valid($::instance_conf->get_gln)) {
      SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text('Client config GLN check digit mismatch. #1 does not seem to be a valid GLN.', $::instance_conf->get_gln));
  }

  for my $item (@{ $self->items_sorted }) {
    if ($item->part->ean && !Algorithm::CheckDigits::CheckDigits('ean')->is_valid($item->part->ean)) {
        SL::X::ZUGFeRDValidation->throw(message => $prefix . $::locale->text('EAN check digit mismatch for part #1. #2 does not seem to be a valid EAN.', $item->part->displayable_name, $item->part->ean));
    }
  }

  return %result;
}

sub create_zugferd_data {
  my ($self)        = @_;
  $self->{_zugferd} = { SL::ZUGFeRD->convert_customer_setting($self->customer->create_zugferd_invoices_for_this_customer) };

  if (!$standards_ids{ $self->{_zugferd}->{profile} }) {
    croak "Profile '" . $self->{_zugferd}->{profile} . "' is not supported";
  }

  my $output        = '';

  my %params        = _validate_data($self);
  $params{ptc_data} = { $self->calculate_prices_and_taxes };
  $params{xml}      = XML::Writer->new(
    OUTPUT          => \$output,
    DATA_MODE       => 1,
    DATA_INDENT     => 2,
    ENCODING        => 'utf-8',
  );

  $params{xml}->xmlDecl();

  # <rsm:CrossIndustryInvoice>
  $params{xml}->startTag("rsm:CrossIndustryInvoice",
                         "xmlns:rsm" => "urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100",
                         "xmlns:qdt" => "urn:un:unece:uncefact:data:standard:QualifiedDataType:100",
                         "xmlns:ram" => "urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100",
                         "xmlns:xs"  => "http://www.w3.org/2001/XMLSchema",
                         "xmlns:udt" => "urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100");

  _exchanged_document_context($self, %params);
  _exchanged_document($self, %params);
  _supply_chain_trade_transaction($self, %params);

  $params{xml}->endTag;
  # </rsm:CrossIndustryInvoice>

  return $output;
}

sub create_zugferd_xmp_data {
  my ($self) = @_;

  return {
    conformance_level  => 'EXTENDED',
    document_file_name => 'factur-x.xml',
    document_type      => 'INVOICE',
    version            => '1.0',
  };
}

sub import_zugferd_data {
  my ($self, $zugferd_parser) = @_;
  validate_pos(@_,
    {
      isa => 'SL::DB::PurchaseInvoice',
    },
    {
      # document class of SL::XMLInvoice
      can => qw(metadata items)
    }
  );

  my %metadata = %{$zugferd_parser->metadata};
  my @items = @{$zugferd_parser->items};

  my $intnotes = t8("ZUGFeRD Import. Type: #1", $metadata{'type'})->translated;
  my $iban = $metadata{'iban'};
  my $invnumber = $metadata{'invnumber'};

  if ( ! ($metadata{'ustid'} or $metadata{'taxnumber'}) ) {
    die t8("Cannot process this invoice: neither VAT ID nor tax ID present.");
  }

  my $vendor = SL::ZUGFeRD::find_vendor($metadata{'ustid'}, $metadata{'taxnumber'});

  die t8("Vendor with VAT ID (#1) and/or tax ID (#2) not found. Please check if the vendor " .
          "#3 exists and whether it has the correct tax ID/VAT ID." ,
           $metadata{'ustid'},
           $metadata{'taxnumber'},
           $metadata{'vendor_name'},
  ) unless $vendor;


  # Check IBAN specified on bill matches the one we've got in
  # the database for this vendor.
  if ($iban) {
    $intnotes .= "\nIBAN: ";
    $intnotes .= $iban ne $vendor->iban ?
    t8("Record IBAN #1 doesn't match vendor IBAN #2", $iban, $vendor->iban)
    : $iban
  }

  # Use invoice creation date as due date if there's no due date
  $metadata{'duedate'} = $metadata{'transdate'} unless defined $metadata{'duedate'};

  # parse dates to kivi if set/valid
  foreach my $key ( qw(transdate duedate) ) {
    next unless defined $metadata{$key};
    $metadata{$key} =~ s/^\s+|\s+$//g;

    if ($metadata{$key} =~ /^([0-9]{4})-?([0-9]{2})-?([0-9]{2})$/) {
    $metadata{$key} = DateTime->new(year  => $1,
                                    month => $2,
                                    day   => $3)->to_kivitendo;
    }
  }

  my $currency = SL::DB::Manager::Currency->find_by(
    name => $metadata{'currency'},
    );

  require SL::DB::Chart;
  my $default_ap_amount_chart = SL::DB::Manager::Chart->find_by(
    id => $::instance_conf->get_expense_accno_id
  );
  # Fallback if there's no default AP amount chart configured
  $default_ap_amount_chart ||= SL::DB::Manager::Chart->find_by(charttype => 'A');

  require SL::DB::Tax;
  require SL::DB::TaxKey;
  my $active_taxkey = $default_ap_amount_chart->get_active_taxkey;
  my $taxes = SL::DB::Manager::Tax->get_all(
    where   => [ chart_categories => {
        like => '%' . $default_ap_amount_chart->category . '%'
      }],
    sort_by => 'taxkey, rate',
  );
  die t8(
    "No tax found for chart #1", $default_ap_amount_chart->displayable_name
  ) unless scalar @{$taxes};

  require SL::DB::RecordTemplate;
  my %template_params;
  my $template_ap = SL::DB::Manager::RecordTemplate->get_first(where => [vendor_id => $vendor->id]);
  if ($template_ap) {
    $template_params{globalproject_id}        = $template_ap->project_id;
    $template_params{payment_id}              = $template_ap->payment_id;
    $template_params{department_id}           = $template_ap->department_id;
    $template_params{ordnumber}               = $template_ap->ordnumber;
    $template_params{transaction_description} = $template_ap->transaction_description;
    $template_params{notes}                   = $template_ap->notes;
  }

  # Try to fill in AP account to book against
  my $ap_chart_id = $template_ap ? $template_ap->ar_ap_chart_id
                  : $::instance_conf->get_ap_chart_id;
  my $ap_chart;
  if ( $ap_chart_id ne '' ) {
    $ap_chart = SL::DB::Manager::Chart->find_by(id => $ap_chart_id);
  } else {
    # If no default account is configured, just use the first AP account found.
    ($ap_chart) = @{SL::DB::Manager::Chart->get_all(
      where   => [ link => 'AP' ],
      sort_by => [ 'accno' ],
    )};
  }

  my $today = DateTime->today_local;
  my $duedate =
      $metadata{duedate} ?
        $metadata{duedate}
    : $vendor->payment ?
        $vendor->payment->calc_date(reference_date => $today)->to_kivitendo
    : $today->to_kivitendo;

  my %params = (
    invoice      => 0,
    vendor_id    => $vendor->id,
    taxzone_id   => $vendor->taxzone_id,
    currency_id  => $currency->id,
    direct_debit => $metadata{'direct_debit'},
    invnumber    => $invnumber,
    transdate    => $metadata{transdate} || $today->to_kivitendo,
    duedate      => $metadata{duedate}   || $today->to_kivitendo,
    taxincluded  => 0,
    intnotes     => $intnotes,
    transactions => [],
    %template_params,
  );

  $self->assign_attributes(%params);

  # parse items
  my $template_item;
  if ($template_ap && scalar @{$template_ap->items}) {
    $template_item = $template_ap->items->[0];
  }
  foreach my $i (@items) {
    my %item = %{$i};

    my $net_total = $item{'subtotal'};

    # set default values for items
    my %line_params;
    $line_params{amount} = $net_total;
    if ($template_item) {
      $line_params{tax_id}     = $template_item->tax->id;
      $line_params{chart}      = $template_item->chart;
      $line_params{project_id} = $template_item->project_id;
    } else {
      my $tax_rate  = $item{'tax_rate'};
         $tax_rate /= 100 if $tax_rate > 1; # XML data is usually in percent
      my $tax   = first { $tax_rate              == $_->rate } @{ $taxes };
         $tax //= first { $active_taxkey->tax_id == $_->id }   @{ $taxes };
         $tax //= $taxes->[0];
      $line_params{tax_id}  = $tax->id;
      $line_params{chart}   = $default_ap_amount_chart;
    }

    $self->add_ap_amount_row(%line_params);
  }
  $self->recalculate_amounts();

  $self->create_ap_row(chart => $ap_chart);

  return $self;
}

1;
