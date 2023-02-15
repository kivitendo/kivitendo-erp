package SL::Controller::ZUGFeRD;
use strict;
use warnings;
use parent qw(SL::Controller::Base);

use SL::DB::RecordTemplate;
use SL::Locale::String qw(t8);
use SL::Helper::DateTime;
use SL::XMLInvoice;
use SL::VATIDNr;
use SL::ZUGFeRD;
use SL::SessionFile;

use XML::LibXML;


__PACKAGE__->run_before('check_auth');

sub action_upload_zugferd {
  my ($self, %params) = @_;

  $self->pre_render();
  $self->render('zugferd/form', title => $::locale->text('Factur-X/ZUGFeRD import'));
}

sub find_vendor_by_taxnumber {
  my $taxnumber = shift @_;

  # 1.1 check if we a have a vendor with this tax number (vendor.taxnumber)
  my $vendor = SL::DB::Manager::Vendor->find_by(
    taxnumber => $taxnumber,
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
        '!taxnumber' => undef,
        '!taxnumber' => '',
        or       => [
          obsolete => undef,
          obsolete => 0,
        ],
      ]);

    foreach my $other_vendor (@{ $vendors }) {
      next unless $other_vendor->taxnumber eq $taxnumber;

      $vendor = $other_vendor;
      last;
    }
  }
}

sub find_vendor_by_ustid {
  my $ustid = shift @_;

  $ustid = SL::VATIDNr->normalize($ustid);

  # 1.1 check if we a have a vendor with this VAT-ID (vendor.ustid)
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

  return $vendor;
}

sub find_vendor {
  my ($ustid, $taxnumber) = @_;
  my $vendor;

  if ( $ustid ) {
    $vendor = find_vendor_by_ustid($ustid);
  }

  if (ref $vendor eq 'SL::DB::Vendor') { return $vendor; }

  if ( $taxnumber ) {
    $vendor = find_vendor_by_taxnumber($taxnumber);
  }

  if (ref $vendor eq 'SL::DB::Vendor') { return $vendor; }

  return undef;
}

sub action_import_zugferd {
  my ($self, %params) = @_;

  my $file = $::form->{file};
  my $file_name = $::form->{file_name};

  my %res;          # result data structure returned by SL::ZUGFeRD->extract_from_{pdf,xml}()
  my $parser;       # SL::XMLInvoice object created by SL::ZUGFeRD->extract_from_{pdf,xml}()
  my $dom;          # DOM object for parsed XML data
  my $template_ap;  # SL::DB::RecordTemplate object
  my $vendor;       # SL::DB::Vendor object

  my $ibanmessage;  # Message to display if vendor's database and invoice IBANs don't match up

  die t8("missing file for action import") unless $file;
  die t8("can only parse a pdf or xml file")      unless $file =~ m/^%PDF|<\?xml/;

  if ( $::form->{file} =~ m/^%PDF/ ) {
    %res = %{SL::ZUGFeRD->extract_from_pdf($::form->{file})}
  } else {
    %res = %{SL::ZUGFeRD->extract_from_xml($::form->{file})};
  }

  if ($res{'result'} != SL::ZUGFeRD::RES_OK()) {
    # An error occurred; log message from parser:
    $::lxdebug->message(LXDebug::DEBUG1(), "Could not extract ZUGFeRD data, error message: " . $res{'message'});
    die(t8("Could not extract Factur-X/ZUGFeRD data, data and error message:") . " $res{'message'}");
  }

  $parser = $res{'invoice_xml'};

  # Shouldn't be neccessary with SL::XMLInvoice doing the heavy lifting, but
  # let's grab it, just in case.
  $dom  = $parser->{dom};

  my %metadata = %{$parser->metadata};
  my @items = @{$parser->items};

  my $iban = $metadata{'iban'};
  my $invnumber = $metadata{'invnumber'};

  if ( ! ($metadata{'ustid'} or $metadata{'taxnumber'}) ) {
    die t8("Cannot process this invoice: neither VAT ID nor tax ID present.");
  }

  $vendor = find_vendor($metadata{'ustid'}, $metadata{'taxnumber'});

  die t8("Please add a valid VAT ID or tax number for this vendor: #1", $metadata{'vendor_name'}) unless $vendor;


  # Create a record template for this imported invoice
  $template_ap = SL::DB::RecordTemplate->new(
      vendor_id=>$vendor->id,
  );

  # Check IBAN specified on bill matches the one we've got in
  # the database for this vendor.
  $ibanmessage = $iban ne $vendor->iban ? "Record IBAN $iban doesn't match vendor IBAN " . $vendor->iban : $iban if $iban;

  # save the zugferd file to session file for reuse in ap.pl
  my $session_file = SL::SessionFile->new($file_name, mode => 'w');
  $session_file->fh->print($file);
  $session_file->fh->close;

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

  # Try to fill in AP account to book against
  my $ap_chart_id = $::instance_conf->get_ap_chart_id;

  unless ( defined $ap_chart_id ) {
    # If no default account is configured, just use the first AP account found.
    my $ap_chart = SL::DB::Manager::Chart->get_all(
      where   => [ link => 'AP' ],
      sort_by => [ 'accno' ],
    );
    $ap_chart_id = ${$ap_chart}[0]->id;
  }

  my $currency = SL::DB::Manager::Currency->find_by(
    name => $metadata{'currency'},
    );

  $template_ap->assign_attributes(
    template_name       => "Faktur-X/ZUGFeRD/XRechnung Import $vendor->name, $invnumber",
    template_type       => 'ap_transaction',
    direct_debit        => $metadata{'direct_debit'},
    notes               => "Faktur-X/ZUGFeRD/XRechnung Import. Type: $metadata{'type'}\nIBAN: " . $ibanmessage,
    taxincluded         => 0,
    currency_id         => $currency->id,
    ar_ap_chart_id      => $ap_chart_id,
    );

  $template_ap->save;

  my $default_ap_amount_chart = SL::DB::Manager::Chart->find_by(charttype => 'A');

  foreach my $i ( @items )
    {
    my %item = %{$i};

    my $net_total = $item{'subtotal'};
    my $desc = $item{'description'};
    my $tax_rate = $item{'tax_rate'} / 100; # XML data is usually in percent

    my $taxes = SL::DB::Manager::Tax->get_all(
      where   => [
        chart_categories => { like => '%' . $default_ap_amount_chart->category . '%' },
        rate => $tax_rate,
      ],
    );

    # If we really can't find any tax definition (a simple rounding error may
    # be sufficient for that to happen), grab the first tax fitting the default
    # category, just like the AP form would do it for manual entry.
    if ( scalar @{$taxes} == 0 ) {
      $taxes = SL::D::ManagerTax->get_all(
        where   => [ chart_categories => { like => '%' . $default_ap_amount_chart->category . '%' } ],
      );
    }

    my $tax = ${$taxes}[0];

    my $item_obj = SL::DB::RecordTemplateItem->new(
      amount1 => $net_total,
      record_template_id => $template_ap->id,
      chart_id      => $default_ap_amount_chart->id,
      tax_id      => $tax->id,
    );
    $item_obj->save;
    }

  $self->redirect_to(
    controller                           => 'ap.pl',
    action                               => 'load_record_template',
    id                                   => $template_ap->id,
    'form_defaults.no_payment_bookings'  => 0,
    'form_defaults.paid_1_suggestion'    => $::form->format_amount(\%::myconfig, $metadata{'total'}, 2),
    'form_defaults.invnumber'            => $invnumber,
    'form_defaults.duedate'              => $metadata{'duedate'},
    'form_defaults.transdate'            => $metadata{'transdate'},
    'form_defaults.notes'                => "ZUGFeRD Import. Type: $metadata{'type'}\nIBAN: " . $ibanmessage,
    'form_defaults.taxincluded'          => 0,
    'form_defaults.direct_debit'         => $metadata{'direct_debit'},
    'form_defaults.zugferd_session_file' => $file_name,
  );

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

sub pre_render {
  my ($self) = @_;

  $::request->{layout}->use_javascript("${_}.js") for qw(
    kivi.ZUGFeRD
  );

  $self->setup_zugferd_action_bar;
}


1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::ZUGFeRD - Controller for importing ZUGFeRD PDF files or XML invoices to kivitendo

=head1 FUNCTIONS

=over 4

=item C<action_upload_zugferd>

Creates a web from with a single upload dialog.

=item C<action_import_zugferd $file>

Expects a single PDF with ZUGFeRD, Factur-X or XRechnung
metadata. Alternatively, it can also process said data as a
standalone XML file.

Checks if the param <C$pdf> is set and a valid PDF or XML
file. Calls helper functions to validate and extract the
ZUGFeRD/Factur-X/XRechnung data. The invoice needs to have a
valid VAT ID (EU) or tax number (Germany) and a vendor with
the same VAT ID or tax number enrolled in Kivitendo.

It parses some basic ZUGFeRD data (invnumber, total net amount,
transdate, duedate, vendor VAT ID, IBAN, etc.) and also
extracts the invoice's items.

If the invoice has a IBAN also, it will be be compared to the
IBAN saved for the vendor (if any). If they  don't match a
warning will be writte in ap.notes. Furthermore the ZUGFeRD
type code will be written to ap.notes. No callback
implemented.

=back

=head1 CAVEAT

This is just a very basic Parser for ZUGFeRD/Factur-X/XRechnung invoices.
We assume that the invoice's creator is a company with a valid
European VAT ID or German tax number and enrolled in
Kivitendo. Currently, implementation is a bit hacky because
invoice import uses AP record templates as a vessel for
generating the AP record form with the imported data filled
in.

=head1 TODO

This implementation could be improved as follows:

=over 4

=item Direct creation of the filled in AP record form

Creating an AP record template in the database is not
very elegant, since it will spam the database with record
templates that become redundant once the invoice has been
booked. It would be preferable to fill in the form directly.

=item Automatic upload of invoice

Right now, one has to use the "Book and upload" button to
upload the raw invoice document to WebDAV or DMS and attach it
to the invoice. This should be a simple matter of setting a
check box when uploading.

=item Handling of vendor invoices

There is no reason this functionality could not be used to
import vendor invoices as well. Since these tend to be very
lengthy, the ability to import them would be very beneficial.

=item Automatic handling of payment purpose

If the ZUGFeRD data has a payment purpose set, this should
be the default for the SEPA-XML export.

=back

=head1 AUTHORS

=over 4

=item Jan Büren E<lt>jan@kivitendo-premium.deE<gt>,

=item Johannes Graßler E<lt>info@computer-grassler.deE<gt>,

=back

=cut
