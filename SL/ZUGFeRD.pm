package SL::ZUGFeRD;

use strict;
use warnings;
use utf8;

use CAM::PDF;
use Data::Dumper;
use List::Util qw(first);
use XML::LibXML;

use SL::Locale::String qw(t8);

use parent qw(Exporter);
our @EXPORT_PROFILES = qw(PROFILE_FACTURX_EXTENDED PROFILE_XRECHNUNG);
our @EXPORT_OK       = (@EXPORT_PROFILES);
our %EXPORT_TAGS     = (PROFILES => \@EXPORT_PROFILES);

use constant PROFILE_FACTURX_EXTENDED => 0;
use constant PROFILE_XRECHNUNG        => 1;

use constant RES_OK                              => 0;
use constant RES_ERR_FILE_OPEN                   => 1;
use constant RES_ERR_NO_XMP_METADATA             => 2;
use constant RES_ERR_NO_XML_INVOICE              => 3;
use constant RES_ERR_NOT_ZUGFERD                 => 4;
use constant RES_ERR_UNSUPPORTED_ZUGFERD_VERSION => 5;

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
  my $doc        = shift;
  my $names_dict = $doc->getValue($doc->getRootDict->{Names}) or return {};
  my $files_tree = $names_dict->{EmbeddedFiles}               or return {};
  my @agenda     = $files_tree;
  my $ret        = {};

  # Hardly ever more than single leaf, but...

  while (@agenda) {
    my $item = $doc->getValue(shift @agenda);

    if ($item->{Kids}) {
      my $kids = $doc->getValue($item->{Kids});
      push @agenda, @$kids

    } else {
      my $nodes = $doc->getValue($item->{Names});
      my @names = map { $doc->getValue($_)} @$nodes;

      while (@names) {
        my ($k, $v)  = splice @names, 0, 2;
        my $ef_node  = $v->{EF};
        my $ef_dict  = $doc->getValue($ef_node);
        my $fnode    = (values %$ef_dict)[0];
        my $any_num  = $fnode->{value};
        my $obj_node = $doc->dereference($any_num);
        my $content  = $doc->decodeOne($obj_node->{value}, 0) // '';

        #print "1\n";

        next if $content !~ m{<rsm:CrossIndustryInvoice};
        #print "2\n";

        my $dom = eval { XML::LibXML->load_xml(string => $content) };
        return $content if $dom && ($dom->documentElement->nodeName eq 'rsm:CrossIndustryInvoice');
      }
    }
  }

  return undef;
}

sub _get_xmp_metadata {
  my ($doc) = @_;

  my $node = $doc->getValue($doc->getRootDict->{Metadata});
  if ($node && $node->{StreamData} && defined($node->{StreamData}->{value})) {
    return $node->{StreamData}->{value};
  }

  return undef;
}

sub extract_from_pdf {
  my ($self, $file_name) = @_;

  my $pdf_doc = CAM::PDF->new($file_name);

  if (!$pdf_doc) {
    return {
      result  => RES_ERR_FILE_OPEN(),
      message => $::locale->text('The file \'#1\' could not be opened for reading.', $file_name),
    };
  }

  my $xmp = _get_xmp_metadata($pdf_doc);
  if (!defined $xmp) {
    return {
      result  => RES_ERR_NO_XMP_METADATA(),
      message => $::locale->text('The file \'#1\' does not contain the required XMP meta data.', $file_name),
    };
  }

  my $bad = {
    result  => RES_ERR_NO_XMP_METADATA(),
    message => $::locale->text('Parsing the XMP metadata failed.'),
  };

  my $dom = eval { XML::LibXML->load_xml(string => $xmp) };

  return $bad if !$dom;

  my $xpc = XML::LibXML::XPathContext->new($dom);
  $xpc->registerNs('rdf', 'http://www.w3.org/1999/02/22-rdf-syntax-ns#');

  my $zugferd_version;

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
    return {
      result  => RES_ERR_NOT_ZUGFERD(),
      message => $::locale->text('The XMP metadata does not declare the Factur-X/ZUGFeRD data.'),
    };
  }

  if ($zugferd_version eq 'unsupported') {
    return {
      result  => RES_ERR_UNSUPPORTED_ZUGFERD_VERSION(),
      message => $::locale->text('The Factur-X/ZUGFeRD version used is not supported.'),
    };
  }

  my $invoice_xml = _extract_zugferd_invoice_xml($pdf_doc);

  if (!defined $invoice_xml) {
    return {
      result  => RES_ERR_NO_XML_INVOICE(),
      message => $::locale->text('The Factur-X/ZUGFeRD XML invoice was not found.'),
    };
  }

  return {
    result       => RES_OK(),
    metadata_xmp => $xmp,
    invoice_xml  => $invoice_xml,
  };
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

    if ($info->{result} != SL::ZUGFeRD::RES_OK()) {
      # An error occurred; log message from parser:
      $::lxdebug->message(LXDebug::DEBUG1(), "Could not extract ZUGFeRD data from $pdf: " . $info->{message});
      return;
    }

    # Parse & handle invoice XML:
    my $dom = XML::LibXML->load_xml(string => $info->{invoice_xml});


=head1 FUNCTIONS

=over 4

=item C<extract_from_pdf> C<$file_name>

Opens an existing PDF in the file system and tries to extract
Factur-X/ZUGFeRD invoice data from it. First it'll parse the XMP
metadata and look for the Factur-X/ZUGFeRD declaration inside. If the
declaration isn't found or the declared version isn't 2p0, an error is
returned.

Otherwise it'll continue to look through all embedded files in the
PDF. The first embedded XML file with a root node of
C<rsm:CrossCountryInvoice> will be returnd.

Always returns a hash ref containing the key C<result>, a number that
can be one of the following constants:

=over 4

=item C<RES_OK> (0): parsing was OK; the returned hash will also
contain the keys C<xmp_metadata> and C<invoice_xml> which will contain
the XML text of the metadata & the Factur-X/ZUGFeRD invoice.

=item C<RES_ERR_…> (all values E<gt> 0): parsing failed; the hash will
also contain a key C<message> which contains a human-readable
information about what exactly failed.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
