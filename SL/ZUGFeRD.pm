package SL::ZUGFeRD;

use strict;
use warnings;
use utf8;

use PDF::API2;
use Data::Dumper;
use List::Util qw(first);
use XML::LibXML;

use SL::Locale::String qw(t8);
use SL::VATIDNr;
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
  [ 0,                                  t8('Do not create Factur-X/ZUGFeRD invoices')                                   ],
  [ PROFILE_FACTURX_EXTENDED() * 2 + 1, t8('Create with profile \'Factur-X 1.01.06/ZUGFeRD 2.2 extended\'')             ],
  [ PROFILE_FACTURX_EXTENDED() * 2 + 2, t8('Create with profile \'Factur-X 1.01.06/ZUGFeRD 2.2 extended\' (test mode)') ],
  [ PROFILE_XRECHNUNG()        * 2 + 1, t8('Create with profile \'XRechnung 2.0.0\'')                                   ],
  [ PROFILE_XRECHNUNG()        * 2 + 2, t8('Create with profile \'XRechnung 2.0.0\' (test mode)')                       ],
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
  my $doc        = shift;
  my %res_fail;

  # unfortunately PDF::API2 has no public facing api to access the actual pdf name dictionaries
  # so we need to use the internal data, just like with PDF::CAM before
  #
  # PDF::API2 will internally read $doc->{pdf}{Root}{Names} for us, but after that every entry
  # in the tree may be an indirect object (Objind) before realising it.
  #
  # The actual embedded files will be located at $doc->{pdf}{Root}{Names}{EmbeddedFiles}
  #

  my $node = $doc->{pdf};
  for (qw(Root Names EmbeddedFiles)) {
    $node = $node->{$_};
    if (!ref $node) {
      return {
        result  => RES_ERR_NO_ATTACHMENT(),
        message => "unexpected unbless node while trying to access $_ node",
      }
    }
    if ('PDF::API2::Basic::PDF::Objind' eq ref $node) {
      $node->realise;
    }
    # after realising it should be a Dict
    if ('PDF::API2::Basic::PDF::Dict' ne ref $node) {
      return {
        result  => RES_ERR_NO_ATTACHMENT(),
        message => "unexpected node type [@{[ref($node)]}] after realising $_ node",
      }
    }
  }

  # now we have an array of possible attachments
  my @agenda     = $node;

  my $parser;  # SL::XMLInvoice object used as return value
  my @res;     # Temporary storage for error messages encountered during
               # attempts to process attachments.

  # Hardly ever more than single leaf, but...

  while (@agenda) {
    my $item = shift @agenda;

    if ($item->realise->{Kids}) {
      my @kids = $item->{Kids}->realise->elements;
      push @agenda, @kids;

    } else {
      my @names = $item->{Names}->realise->elements;

      TRY_NEXT:
      while (@names) {
        my ($k, $v)  = splice @names, 0, 2;
        my $fnode    = $v->realise->{EF}->realise->{F}->realise;

        $fnode->read_stream(1);

        my $content  = $fnode->{' stream'};

        $parser = SL::XMLInvoice->new($content);

        # Caveat: this will only ever catch the first attachment looking like
        #         an XML invoice.
        if ( $parser->{result} == SL::XMLInvoice::RES_OK ){
          return $parser;
        } else {
          push @res, t8(
            "Could not parse PDF embedded attachment #1: #2",
            $k,
            $parser->{result}
          );
        }
      }
    }
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

sub _get_xmp_metadata {
  my ($doc) = @_;

  $doc->xmpMetadata;
}

sub extract_from_pdf {
  my ($self, $file_name) = @_;
  my @warnings;

  my $pdf_doc = PDF::API2->openScalar($file_name);

  if (!$pdf_doc) {
    return {
      result  => RES_ERR_FILE_OPEN,
      message => $::locale->text('The file \'#1\' could not be opened for reading.', $file_name),
    };
  }

  my $xmp = _get_xmp_metadata($pdf_doc);

  if (!defined $xmp) {
      push @warnings, $::locale->text('The file \'#1\' does not contain the required XMP meta data.', $file_name);
  } else {
    my $dom = eval { XML::LibXML->load_xml(string => $xmp, expand_entities => 0) };

    push @warnings, $::locale->text('Parsing the XMP metadata failed.'), if !$dom;

    my $xpc = XML::LibXML::XPathContext->new($dom);
    $xpc->registerNs('rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#');

    my $zugferd_version;

    my $test = $xpc->findnodes('/x:xmpmeta/rdf:RDF/rdf:Description');

    foreach my $node ($xpc->findnodes('/x:xmpmeta/rdf:RDF/rdf:Description')) {
      my $ns = first { ref($_) eq 'XML::LibXML::Namespace' } $node->attributes;
      next unless $ns;

      if ($ns->getData =~ m{urn:zugferd:pdfa:CrossIndustryDocument:invoice:2p0}) {
        $zugferd_version = 'zugferd:2p0';
        last;
      }

      if ($ns->getData =~ m{urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0}) {
        $zugferd_version = 'factur-x:1p0';
        last;
      }

      if ($ns->getData =~ m{zugferd|factur-x}i) {
        $zugferd_version = 'unsupported';
        last;
      }
    }

    if (!$zugferd_version) {
        push @warnings, $::locale->text('The XMP metadata does not declare the Factur-X/ZUGFeRD data.'),
    }

    if (($zugferd_version // '') eq 'unsupported') {
        push @warnings, $::locale->text('The Factur-X/ZUGFeRD version used is not supported.'),
    }
  }

  my $invoice_xml = _extract_zugferd_invoice_xml($pdf_doc);

  my %res;

  %res = (
    result       => $invoice_xml->{result},
    message      => $invoice_xml->{message},
    metadata_xmp => $xmp,
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
    metadata_xmp => undef,
    invoice_xml  => $invoice_xml,
    warnings     => [],
  );

  return \%res;
}

sub find_vendor_by_taxnumber {
  my $taxnumber = shift @_;

  require SL::DB::Vendor;

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
  require SL::DB::Vendor;

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

=item C<metadata_xmp> - The XMP metadata extracted from the Factur-X/ZUGFeRD invoice (if present)

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

=item C<metadata_xmp> - Always undef and only present to let downstream code expecting its presence fail gracefully.

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
