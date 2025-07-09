package SL::XMLInvoice;

use strict;
use warnings;

use List::Util qw(first);
use XML::LibXML;

use SL::Locale::String qw(t8);
use SL::XMLInvoice::UBL;
use SL::XMLInvoice::CrossIndustryInvoice;
use SL::XMLInvoice::CrossIndustryDocument;

use constant RES_OK => 0;
use constant RES_XML_PARSING_FAILED => 1;
use constant RES_UNKNOWN_ROOT_NODE_TYPE => 2;

our @document_modules = qw(
  SL::XMLInvoice::CrossIndustryDocument
  SL::XMLInvoice::CrossIndustryInvoice
  SL::XMLInvoice::UBL
);

=head1 NAME

SL::XMLInvoice - Top level factory class for XML Invoice parsers.

=head1 DESCRIPTION

C<SL::XMLInvoice> is an abstraction layer allowing the application to pass any
supported XML invoice document for parsing, with C<SL::XMLInvoice> handling all
details from there: depending on its document type declaration, this class will
pick and instatiate the appropriate child class for parsing the document and
return an object exposing its data with the standardized structure outlined
below.

See L <SL::XMLInvoice::Base>
for details on the shared interface of the returned instances.

=head1 SYNOPSIS

  # $xml_data contains an XML document as flat scalar
  my $invoice_parser = SL::XMLInvoice->new($xml_data);

  # %metadata is a hash of document level metadata items
  my %metadata = %{$invoice_parser->metadata};

  # @items is an array of hashes, each representing a line
  # item on the bill
  my @items = @{$invoice_parser->items};

=cut

sub new {
  my ($class, $xml_data) = @_;
  my $self = {};

  $self->{message} = '';
  $self->{dom} = eval { XML::LibXML->load_xml(string => $xml_data, expand_entities => 0) };

  if ( ! $self->{dom} ) {
    $self->{message} = t8("Parsing the XML data failed: #1", $xml_data);
    $self->{result} = RES_XML_PARSING_FAILED;
    return $self;
  }

  # Determine parser class to use
  my $type = first {
    $_->check_signature($self->{dom})
  } @document_modules;

  unless ( $type ) {
    $self->{result} = RES_UNKNOWN_ROOT_NODE_TYPE;

    my @supported = map { $_->supported } @document_modules;

    $self->{message} =  t8("Could not parse XML Invoice: unknown XML invoice type\nsupported: #1",
                           join ",\n", @supported
                        );
    return $self;
  }

  bless $self, $type;

  # Implementation sanity check for child classes: make sure they are aware of
  # the keys the hash returned by their metadata() method must contain.
  my @missing_data_keys = grep { !${$self->_data_keys}{$_} } @{ $self->data_keys };
  if ( scalar(@missing_data_keys) > 0 ) {
    die "Incomplete implementation: the following metadata keys appear to be missing from $type: " . join(", ", @missing_data_keys);
  }

  # Implementation sanity check for child classes: make sure they are aware of
  # the keys the hashes returned by their items() method must contain.
  my @missing_item_keys = ();
  foreach my $item_key ( @{$self->item_keys} ) {
    unless ( ${$self->_item_keys}{$item_key}) { push @missing_item_keys, $item_key; }
  }
  if ( scalar(@missing_item_keys) > 0 ) {
    die "Incomplete implementation: the following item keys appear to be missing from $type: " . join(", ", @missing_item_keys);
  }

  $self->parse_xml;

  # Ensure these methods are implemented in the child class
  $self->metadata;
  $self->items;

  $self->{result} = RES_OK;
  return $self;
}

1;

