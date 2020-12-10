package SL::Controller::ZUGFeRD;
use strict;
use parent qw(SL::Controller::Base);

use SL::DB::RecordTemplate;
use SL::Locale::String qw(t8);
use SL::Helper::DateTime;
use SL::VATIDNr;
use SL::ZUGFeRD;

use XML::LibXML;


__PACKAGE__->run_before('check_auth');

sub action_upload_zugferd {
  my ($self, %params) = @_;

  $self->setup_zugferd_action_bar;
  $self->render('zugferd/form', title => $::locale->text('Factur-X/ZUGFeRD import'));
}

sub action_import_zugferd {
  my ($self, %params) = @_;

  die t8("missing file for action import") unless $::form->{file};
  die t8("can only parse a pdf file")      unless $::form->{file} =~ m/^%PDF/;

  my $info = SL::ZUGFeRD->extract_from_pdf($::form->{file});

  if ($info->{result} != SL::ZUGFeRD::RES_OK()) {
    # An error occurred; log message from parser:
    $::lxdebug->message(LXDebug::DEBUG1(), "Could not extract ZUGFeRD data, error message: " . $info->{message});
    die t8("Could not extract Factur-X/ZUGFeRD data, data and error message:") . $info->{message};
  }
  # valid ZUGFeRD metadata
  my $dom   = XML::LibXML->load_xml(string => $info->{invoice_xml});

  # 1. check if ZUGFeRD SellerTradeParty has a VAT-ID
  my $ustid = $dom->findnodes('//ram:SellerTradeParty/ram:SpecifiedTaxRegistration')->string_value;
  die t8("No VAT Info for this Factur-X/ZUGFeRD invoice," .
         " please ask your vendor to add this for his Factur-X/ZUGFeRD data.") unless $ustid;

  $ustid = SL::VATIDNr->normalize($ustid);

  # 1.1 check if we a have a vendor with this VAT-ID (vendor.ustid)
  my $vc     = $dom->findnodes('//ram:SellerTradeParty/ram:Name')->string_value;
  my $vendor = SL::DB::Manager::Vendor->find_by(
    ustid => $ustid,
    or    => [
      obsolete => undef,
      obsolete => 0,
    ]);

  if (!$vendor) {
    # 1.2 If no vendor with the exact VAT ID number is found, the
    # number might be stored slightly different in the database
    # (e.g. with spaces breaking up groups of numbers). Iterate over
    # all existing vendors with VAT ID numbers, normalize their
    # representation and compare those.

    my $vendors = SL::DB::Manager::Vendor->get_all(
      where => [
        '!ustid' => undef,
        '!ustid' => '',
        or       => [
          obsolete => undef,
          obsolete => 0,
        ],
      ]);

    foreach my $other_vendor (@{ $vendors }) {
      next unless SL::VATIDNr->normalize($other_vendor->ustid) eq $ustid;

      $vendor = $other_vendor;
      last;
    }
  }

  die t8("Please add a valid VAT-ID for this vendor: #1", $vc) unless (ref $vendor eq 'SL::DB::Vendor');

  # 2. check if we have a ap record template for this vendor (TODO only the oldest template is choosen)
  my $template_ap = SL::DB::Manager::RecordTemplate->get_first(where => [vendor_id => $vendor->id]);
  die t8("No AP Record Template for this vendor found, please add one") unless (ref $template_ap eq 'SL::DB::RecordTemplate');


  # 3. parse the zugferd data and fill the ap record template
  # -> no need to check sign (credit notes will be negative) just record thei ZUGFeRD type in ap.notes
  # -> check direct debit (defaults to no)
  # -> set amount (net amount) and unset taxincluded
  #    (template and user cares for tax and if there is more than one booking accno)
  # -> date (can be empty)
  # -> duedate (may be empty)
  # -> compare record iban and generate a warning if this differs from vendor's master data iban
  my $total     = $dom->findnodes('//ram:SpecifiedTradeSettlementHeaderMonetarySummation' .
                                  '/ram:TaxBasisTotalAmount')->string_value;

  my $invnumber = $dom->findnodes('//rsm:ExchangedDocument/ram:ID')->string_value;

  # parse dates to kivi if set/valid
  my ($transdate, $duedate, $dt_to_kivi, $due_dt_to_kivi);
  $transdate = $dom->findnodes('//ram:IssueDateTime')->string_value;
  $duedate   = $dom->findnodes('//ram:DueDateDateTime')->string_value;
  $transdate =~ s/^\s+|\s+$//g;
  $duedate   =~ s/^\s+|\s+$//g;

  if ($transdate =~ /^[0-9]{8}$/) {
    $dt_to_kivi = DateTime->new(year  => substr($transdate,0,4),
                                month => substr ($transdate,4,2),
                                day   => substr($transdate,6,2))->to_kivitendo;
  }
  if ($duedate =~ /^[0-9]{8}$/) {
    $due_dt_to_kivi = DateTime->new(year  => substr($duedate,0,4),
                                    month => substr ($duedate,4,2),
                                    day   => substr($duedate,6,2))->to_kivitendo;
  }

  my $type = $dom->findnodes('//rsm:ExchangedDocument/ram:TypeCode')->string_value;

  my $dd   = $dom->findnodes('//ram:ApplicableHeaderTradeSettlement' .
                             '/ram:SpecifiedTradeSettlementPaymentMeans/ram:TypeCode')->string_value;
  my $direct_debit = $dd == 59 ? 1 : 0;

  my $iban = $dom->findnodes('//ram:ApplicableHeaderTradeSettlement/ram:SpecifiedTradeSettlementPaymentMeans' .
                             '/ram:PayeePartyCreditorFinancialAccount/ram:IBANID')->string_value;
  my $ibanmessage;
  $ibanmessage = $iban ne $vendor->iban ? "Record IBAN $iban doesn't match vendor IBAN " . $vendor->iban : $iban if $iban;

  my $url = $self->url_for(
    controller                           => 'ap.pl',
    action                               => 'load_record_template',
    id                                   => $template_ap->id,
    'form_defaults.amount_1'             => $::form->format_amount(\%::myconfig, $total, 2),
    'form_defaults.transdate'            => $dt_to_kivi,
    'form_defaults.invnumber'            => $invnumber,
    'form_defaults.duedate'              => $due_dt_to_kivi,
    'form_defaults.no_payment_bookings'  => 0,
    'form_defaults.paid_1_suggestion'    => $::form->format_amount(\%::myconfig, $total, 2),
    'form_defaults.notes'                => "ZUGFeRD Import. Type: $type\nIBAN: " . $ibanmessage,
    'form_defaults.taxincluded'          => 0,
    'form_defaults.direct_debit'          => $direct_debit,
  );

  $self->redirect_to($url);

}

sub check_auth {
  $::auth->assert('ap_transactions');
}
sub setup_zugferd_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        $::locale->text('Import'),
        submit    => [ '#form', { action => 'ZUGFeRD/import_zugferd' } ],
        accesskey => 'enter',
      ],
    );
  }
}


1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::ZUGFeRD
Controller for importing ZUGFeRD pdf files to kivitendo

=head1 FUNCTIONS

=over 4

=item C<action_upload_zugferd>

Creates a web from with a single upload dialog.

=item C<action_import_zugferd $pdf>

Expects a single pdf with ZUGFeRD 2.0 metadata.
Checks if the param <C$pdf> is set and a valid pdf file.
Calls helper functions to validate and extract the ZUGFeRD data.
Needs a valid VAT ID (EU) for this vendor and
expects one ap template for this vendor in kivitendo.

Parses some basic ZUGFeRD data (invnumber, total net amount,
transdate, duedate, vendor VAT ID, IBAN) and uses the first
found ap template for this vendor to fill this template with
ZUGFeRD data.
If the vendor's master data contain a IBAN and the
ZUGFeRD record has a IBAN also these values will be compared.
If they  don't match a warning will be writte in ap.notes.
Furthermore the ZUGFeRD type code will be written to ap.notes.
No callback implemented.

=back

=head1 TODO and CAVEAT

This is just a very basic Parser for ZUGFeRD data.
We assume that the ZUGFeRD generator is a company with a
valid European VAT ID. Furthermore this vendor needs only
one and just noe ap template (the first match will be used).

The ZUGFeRD data should also be extracted in the helper package
and maybe a model should be used for this.
The user should set one ap template as a default for ZUGFeRD.
The ZUGFeRD pdf should be written to WebDAV or DMS.
If the ZUGFeRD data has a payment purpose set, this should
be the default for the SEPA-XML export.


=head1 AUTHOR

Jan Büren E<lt>jan@kivitendo-premium.deE<gt>,

=cut
