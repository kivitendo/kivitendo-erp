package SL::ZUGFeRD;

use strict;
use warnings;
use utf8;

use File::Temp;
use File::Slurp qw(slurp);
use List::Util qw(first);
use Poppler;
use XML::LibXML;

use SL::Locale::String qw(t8);
use SL::XMLInvoice;

use parent qw(Exporter);
our @EXPORT_PROFILES = qw(PROFILE_FACTURX_EXTENDED PROFILE_XRECHNUNG);
our @EXPORT_OK       = (@EXPORT_PROFILES);
our %EXPORT_TAGS     = (PROFILES => \@EXPORT_PROFILES);

use constant PROFILE_FACTURX_EXTENDED => 0;
use constant PROFILE_XRECHNUNG        => 1;

use constant RES_OK => 0;
use constant RES_ERR_FILE_OPEN => -1;
use constant RES_ERR_NO_ATTACHMENT => -2;

our @customer_settings = (
  [ 0,                                  t8('Do not create Factur-X/ZUGFeRD invoices')                                    ],
  [ PROFILE_FACTURX_EXTENDED() * 2 + 1, t8('Create with profile \'Factur-X 1.0.05/ZUGFeRD 2.1.1 extended\'')             ],
  [ PROFILE_FACTURX_EXTENDED() * 2 + 2, t8('Create with profile \'Factur-X 1.0.05/ZUGFeRD 2.1.1 extended\' (test mode)') ],
  [ PROFILE_XRECHNUNG()        * 2 + 1, t8('Create with profile \'XRechnung 2.0.0\'')                                    ],
  [ PROFILE_XRECHNUNG()        * 2 + 2, t8('Create with profile \'XRechnung 2.0.0\' (test mode)')                        ],
);

sub convert_customer_setting {
  my ($class, $customer_setting) = @_;

  return () if ($customer_setting <= 0) || ($customer_setting >= scalar(@customer_settings));

  return (
    profile   => int(($customer_setting - 1) / 2),
    test_mode => ($customer_setting - 1) % 2,
  );
}

sub _extract_zugferd_invoice_xml {
  my $file        = shift;
  my (%res_fail, @res, @attachments);

  my $userspath       = SL::System::Process::exe_dir() . "/" . $::lx_office_conf{paths}->{userspath};

  my $pdf = eval { Poppler::Document->new_from_file($file) };

  unless ( $pdf ) { return {
      'result'  => RES_ERR_NO_ATTACHMENT(),
      'message' => "Cannot open PDF file: $!",
    };
  }

  my $tmpfile = File::Temp->new(
    'zugferd-import-XXXXXXXX',
    DIR    => $userspath,
    UNLINK => 1,
  );

  @attachments = eval { $pdf->get_attachments };

  if ( scalar @attachments == 0 ) {
        return {
        'result'  => RES_ERR_NO_ATTACHMENT(),
        'message' => "PDF file does not have any attachments.",
      };
    }

  my $i = 0;

  foreach my $attachment ( @attachments ) {
    my $retval = eval { Poppler::Attachment::save($attachment, $tmpfile->filename) };
    unless ( $retval ) {
      $i++;
      next;
    }
    my $xml = slurp($tmpfile->filename);
    my $parser = SL::XMLInvoice->new($xml);
    if ( $parser->{result} == SL::XMLInvoice::RES_OK ){
      return $parser;
    } else {
      push @res, t8(
        "Could not parse PDF embedded attachment #1: #2",
        $i,
        $parser->{result}
        );
    }
    $i++;
  }

  # There's going to be at least one attachment that failed to parse as XML by
  # this point - if there were no attachments at all, we would have bailed out
  # a lot earlier.

  %res_fail = (
    result  => RES_ERR_FILE_OPEN,
    message => join("; ", @res),
  );

  return \%res_fail;
}

sub extract_from_pdf {
  my ($self, $file_name) = @_;
  my @warnings;

  my $invoice_xml = _extract_zugferd_invoice_xml($file_name);

  my %res;

  %res = (
    result       => $invoice_xml->{result},
    message      => $invoice_xml->{message},
    invoice_xml  => $invoice_xml,
    warnings     => \@warnings,
  );

  return \%res;
}

sub extract_from_xml {
  my ($self, $data) = @_;

  my %res;

  my $invoice_xml = SL::XMLInvoice->new($data);

  %res = (
    result       => $invoice_xml->{result},
    message      => $invoice_xml->{message},
    invoice_xml  => $invoice_xml,
    warnings     => (),
  );

  return \%res;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::ZUGFeRD - Helper functions for dealing with PDFs containing Factur-X/ZUGFeRD invoice data

=head1 SYNOPSIS

    my $pdf  = '/path/to/my.pdf';
    my $info = SL::ZUGFeRD->extract_from_pdf($pdf);

    my $xml  = '<?xml version="1.0" encoding="UTF-8"?> ...';
    my $info = SL::ZUGFeRD->extract_from_xml($xml);

    if ($info->{result} != SL::ZUGFeRD::RES_OK()) {
      # An error occurred; log message from parser:
      $::lxdebug->message(LXDebug::DEBUG1(), "Could not extract ZUGFeRD data from $pdf: " . $info->{message});
      return;
    }

    # Access invoice XML data:
    my $inv = ${$info}{'invoice_xml};
    my %metadata = %{$inv->metadata};
    my @items = @{$inv->items};
    my $dom = $inv->dom;


=head1 FUNCTIONS

=head2 extract_from_pdf E<lt>file_nameE<gt>

Opens an existing PDF file in the file system and tries to extract
Factur-X/XRechnung/ZUGFeRD invoice data from it. First it'll parse the XMP
metadata and look for the Factur-X/ZUGFeRD declaration inside. If the
declaration isn't found or the declared version isn't 2p0, an warning is
recorded in the returned data structure's C<warnings> key.

Regardless of metadata presence, it will continue to iterate over all files
embedded in the PDF and attempt to parse them with SL::XMLInvoice. If it
succeeds, the first SL::XMLInvoice object that indicates successful parsing is
returned.

Always returns a hash ref containing the key C<result>, a number that
can be one of the following constants:

=over 4

=item C<RES_OK> (0): parsing was OK.

=item C<RES_ERR_…> (all values != 0): parsing failed. Values > 0 indicate a failure
in C<SL::XMLInvoice>, Values < 0 indicate a failure in C<SL::ZUGFeRD>.

=back

Other than that, the hash ref contains the following keys:

=over 4

=item C<message> - An error message detailing the problem upon nonzero C<result>, undef otherwise.

=item C<invoice_xml> - An SL::XMLInvoice object holding the data extracted from the parsed XML invoice.

=item C<warnings> - Warnings encountered upon extracting/parsing XML files (if any)

=back

=head2 extract_from_xml E<lt>stringE<gt>

Takes a string containing an XML document with Factur-X/XRechnung/ZUGFeRD
invoice data and attempts to parse it using C<SL::XMLInvoice>.

If parsing is successful, an SL::XMLInvoice object containing the document's
parsed data is returned.

This method always returns a hash ref containing the key C<result>, a number that
can be one of the following constants:

=over 4

=item C<RES_OK> (0): parsing was OK.

=item C<RES_ERR_…> (all values != 0): parsing failed. Values > 0 indicate a failure
in C<SL::XMLInvoice>, Values < 0 indicate a failure in C<SL::ZUGFeRD>.

=back

Other than that, the hash ref contains the following keys:

=over 4

=item C<message> - An error message detailing the problem upon nonzero C<result>, undef otherwise.

=item C<invoice_xml> - An SL::XMLInvoice object holding the data extracted from the parsed XML invoice.

=item C<warnings> - Warnings encountered upon extracting/parsing XML data (if any)

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHORS

=over 4

=item Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=item Johannes Graßler E<lt>info@computer-grassler.deE<gt>

=back

=cut
