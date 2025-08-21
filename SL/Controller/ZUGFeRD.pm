package SL::Controller::ZUGFeRD;
use strict;
use warnings;
use parent qw(SL::Controller::Base);

use SL::DB::RecordTemplate;
use SL::Locale::String qw(t8);
use SL::Helper::DateTime;
use SL::XMLInvoice;
use SL::ZUGFeRD;
use SL::SessionFile;
use SL::Helper::Number qw(_format_total);

use XML::LibXML;
use List::Util qw(first);


__PACKAGE__->run_before('check_auth');

sub action_upload_zugferd {
  my ($self, %params) = @_;

  $self->pre_render();
  $self->render('zugferd/form', title => $::locale->text('Factur-X/ZUGFeRD import'));
}


sub action_import_zugferd {
  my ($self, %params) = @_;

  my $file = $::form->{file};
  my $file_name = $::form->{file_name};

  my %res; # result data structure returned by SL::ZUGFeRD->extract_from_{pdf,xml}()

  die t8("missing file for action import")   unless $file;
  die t8("can only parse a pdf or xml file") unless $file =~ m/^%PDF|<\?xml/;

  if ( $::form->{file} =~ m/^%PDF/ ) {
    %res = %{SL::ZUGFeRD->extract_from_pdf($file)};
  } else {
    %res = %{SL::ZUGFeRD->extract_from_xml($file)};
  }

  if ($res{'result'} != SL::ZUGFeRD::RES_OK()) {
    # An error occurred; log message from parser:
    die(t8("Could not extract Factur-X/ZUGFeRD data, data and error message:") . " $res{'message'}");
  }

  my $form_defaults = $self->build_ap_transaction_form_defaults(\%res);

  # save the zugferd file to session file for reuse in ap.pl
  my $session_file = SL::SessionFile->new($file_name, mode => 'w');
  $session_file->fh->print($file);
  $session_file->fh->close;
  $form_defaults->{zugferd_session_file} = $file_name;

  $form_defaults->{callback} = $self->url_for(action => 'upload_zugferd');

  $self->redirect_to(
    controller    => 'ap.pl',
    action        => 'load_zugferd',
    form_defaults => $form_defaults,
  );
}

sub build_ap_transaction_form_defaults {
  my ($self, $data, %params) = @_;
  my $vendor = $params{vendor};

  my $parser = $data->{'invoice_xml'};

  my %metadata = %{$parser->metadata};
  my @items = @{$parser->items};

  my $intnotes = t8("ZUGFeRD Import. Type: #1", $metadata{'type'})->translated;
  my $iban = $metadata{'iban'};
  my $invnumber = $metadata{'invnumber'};

  if ($vendor) {
    if ($metadata{'ustid'} && $vendor->ustid && ($metadata{'ustid'} ne $vendor->ustid)) {
      $intnotes .= "\n" . t8('USt-IdNr.') . ': '
      . t8("Record VAT ID #1 doesn't match vendor VAT ID #2", $metadata{'ustid'}, $vendor->ustid);
    }
    if ($metadata{'taxnumber'} && $vendor->taxnumber && ($metadata{'taxnumber'} ne $vendor->taxnumber)) {
      $intnotes .= "\n" . t8("Tax Number") . ': '
      . t8("Record tax ID #1 doesn't match vendor tax ID #2", $metadata{'taxnumber'}, $vendor->taxnumber);
    }
  } else {
    if ( ! ($metadata{'ustid'} or $metadata{'taxnumber'}) ) {
      die t8("Cannot process this invoice: neither VAT ID nor tax ID present.");
    }

    $vendor = SL::ZUGFeRD::find_vendor($metadata{'ustid'}, $metadata{'taxnumber'});

    die t8("Vendor with VAT ID (#1) and/or tax ID (#2) not found. Please check if the vendor " .
            "#3 exists and whether it has the correct tax ID/VAT ID." ,
             $metadata{'ustid'},
             $metadata{'taxnumber'},
             $metadata{'vendor_name'},
    ) unless $vendor;
  }


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

  # Try to fill in AP account to book against
  my $ap_chart_id = $::instance_conf->get_ap_chart_id;

  unless ( defined $ap_chart_id ) {
    # If no default account is configured, just use the first AP account found.
    my ($ap_chart) = @{SL::DB::Manager::Chart->get_all(
      where   => [ link => 'AP' ],
      sort_by => [ 'accno' ],
    )};
    $ap_chart_id = $ap_chart->id;
  }

  my $currency = SL::DB::Manager::Currency->find_by(
    name => $metadata{'currency'},
    );

  my $default_ap_amount_chart = SL::DB::Manager::Chart->find_by(
    id => $::instance_conf->get_expense_accno_id
  );
  # Fallback if there's no default AP amount chart configured
  $default_ap_amount_chart ||= SL::DB::Manager::Chart->find_by(charttype => 'A');

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


  my %item_form = ();
  if ($self->use_totals_for_ap_transaction($parser)) {
    # use tax totals instead to fill in the ap lines

    my $tax_totals = $parser->tax_totals;

    my $row = 0;
    for my $tax_row (@$tax_totals) {
      $row++;

      my $tax;
      if ($tax_row->{category_code} =~ /S/) {
        # Standard tax
        my $tax_rate = $tax_row->{tax_rate} / 100;
        $tax = first { $tax_rate == $_->rate } @$taxes;
        die t8('Can not find a tax for tax rate #1', $tax_rate) unless $tax;
      } elsif ($tax_row->{category_code} =~ /[ZE]/) {
        # Zero tax or tax Exempt
        $tax = first { 0 == $_->rate } @$taxes;
        die t8('Can not find a tax for tax rate #1', 0) unless $tax;
      } else {
        die t8('Tax category code #1 is not supported at the moment', $tax_row->{category_code});
      }

      $item_form{"AP_amount_chart_id_${row}"}          = $default_ap_amount_chart->id;
      $item_form{"previous_AP_amount_chart_id_${row}"} = $default_ap_amount_chart->id;
      $item_form{"amount_${row}"}                      = _format_total($tax_row->{net_amount});
      $item_form{"taxchart_${row}"}                    = $tax->id . '--' . $tax->rate;
    }

    # special case: untaxed positions like deposit don't show up in the tax blocks
    # invariant:
    # net_amount + tax + [UntaxedAmount] = amount

    my $untaxed_delta = $metadata{gross_total} - $metadata{net_total} - $metadata{tax_total};
    if ($untaxed_delta > 0.005) {
      $row++;

      # Zero tax or tax Exempt
      my $tax = first { 0 == $_->rate } @$taxes;
      die t8('Can not find a tax for tax rate #1', 0) unless $tax;

      $item_form{"AP_amount_chart_id_${row}"}          = $default_ap_amount_chart->id;
      $item_form{"previous_AP_amount_chart_id_${row}"} = $default_ap_amount_chart->id;
      $item_form{"amount_${row}"}                      = _format_total($untaxed_delta);
      $item_form{"taxchart_${row}"}                    = $tax->id . '--' . $tax->rate;
    }

    $item_form{rowcount} = $row;

  } else {
    # else: try to replicate the items in the ap transaction

    # parse items
    my $row = 0;
    foreach my $i (@items) {
      $row++;

      my %item = %{$i};

      my $net_total = $::form->format_amount(\%::myconfig, $item{'subtotal'}, 2);

      my $tax_rate = $item{'tax_rate'};
      $tax_rate /= 100 if $tax_rate > 1; # XML data is usually in percent

      my $tax   = first { $tax_rate              == $_->rate } @{ $taxes };
      $tax    //= first { $active_taxkey->tax_id == $_->id }   @{ $taxes };
      $tax    //= $taxes->[0];

      $item_form{"AP_amount_chart_id_${row}"}          = $default_ap_amount_chart->id;
      $item_form{"previous_AP_amount_chart_id_${row}"} = $default_ap_amount_chart->id;
      $item_form{"amount_${row}"}                      = $net_total;
      $item_form{"taxchart_${row}"}                    = $tax->id . '--' . $tax->rate;
    }
    $item_form{rowcount} = $row;
  }

  return {
    vendor_id            => $vendor->id,
    vendor               => $vendor->name,
    invnumber            => $invnumber,
    transdate            => $metadata{'transdate'},
    duedate              => $metadata{'duedate'},
    no_payment_bookings  => 0,
    intnotes             => $intnotes,
    taxincluded          => 0,
    direct_debit         => $metadata{'direct_debit'},
    currency             => $currency->name,
    AP_chart_id          => $ap_chart_id,
    paid_1_suggestion    => $::form->format_amount(\%::myconfig, $metadata{'total'}, 2),
    %item_form,
  },
}

sub use_totals_for_ap_transaction {
  my ($self, $parser) = @_;

  return 0 if !$parser->can('tax_totals');

  return $::instance_conf->get_zugferd_ap_transaction_use_totals;
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
warning will be writte in ap.intnotes. Furthermore the ZUGFeRD
type code will be written to ap.intnotes. No callback
implemented.

=back

=head1 CAVEAT

This is just a very basic Parser for ZUGFeRD/Factur-X/XRechnung invoices.
We assume that the invoice's creator is a company with a valid
European VAT ID or German tax number and enrolled in
Kivitendo.

=head1 TODO

This implementation could be improved as follows:

=over 4

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
