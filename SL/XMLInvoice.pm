package SL::XMLInvoice;

use strict;
use warnings;

use SL::Locale::String qw(t8);
use XML::LibXML;

use constant RES_OK => 0;
use constant RES_XML_PARSING_FAILED => 1;
use constant RES_UNKNOWN_ROOT_NODE_TYPE => 2;

=head1 NAME

SL::XMLInvoice - Top level factory class for XML Invoice parsers.

=head1 DESCRIPTION

C<SL::XMLInvoice> is an abstraction layer allowing the application to pass any
supported XML invoice document for parsing, with C<SL::XMLInvoice> handling all
details from there: depending on its document type declaration, this class will
pick and instatiate the appropriate child class for parsing the document and
return an object exposing its data with the standardized structure outlined
below.

=head1 SYNOPSIS

  # $xml_data contains an XML document as flat scalar
  my $invoice_parser = SL::XMLInvoice->new($xml_data);

  # %metadata is a hash of document level metadata items
  my %metadata = %{$invoice_parser->metadata};

  # @items is an array of hashes, each representing a line
  # item on the bill
  my @items = @{$invoice_parser->items};

=cut

=head1 ATTRIBUTES

=over 4

=item dom

A XML::LibXML document object model (DOM) object created from the XML data supplied.

=item message

Will contain a detailed error message if the C<result> attribute is anything
other than C<SL::XMLInvoice::RES_OK>.

=item result

A status field indicating whether the supplied XML data could be parsed. It
can take the following values:

=item SL::XMLInvoice::RES_OK

File has been parsed successfully.

=item SL::XMLInvoice::RES_XML_PARSING FAILED

Parsing the file failed.

=item SL::XMLInvoice::RES_UNKNOWN_ROOT_NODE_TYPE

The root node is of an unknown type. Currently, C<rsm:CrossIndustryInvoice> and
C<ubl:Invoice> are supported.

=back

=cut

=head1 METHODS

=head2 Data structure definition methods (only in C<SL::XMLInvoice>)

These methods are only implemented in C<SL::XMLInvoice> itself and define the
data structures to be exposed by any child classes.

=over 4

=item data_keys()

Returns all keys the hash returned by any child's C<metadata()> method must
contain. If you add keys to this list, you need to add them to all classes
inheriting from C<SL::XMLInvoice> as well. An application may use this method
to discover the metadata keys guaranteed to be present.

=cut

sub data_keys {
  my @keys = (
    'currency',      # The bill's currency, such as "EUR"
    'direct_debit',  # Boolean: whether the bill will get paid by direct debit (1) or not (0)
    'duedate',       # The bill's due date in YYYY-MM-DD format.
    'gross_total',   # The invoice's sum total with tax included
    'iban',          # The creditor's IBAN
    'invnumber',     # The invoice's number
    'net_total',     # The invoice's sum total without tax
    'taxnumber',     # The creditor's tax number (Steuernummer in Germany). May be present if
                     # there is no VAT ID (USTiD in Germany).
    'transdate',     # The date the invoice was issued in YYYY-MM-DD format.
    'type',          # Numeric invoice type code, e.g. 380
    'ustid',         # The creditor's UStID.
    'vendor_name',   # The vendor's company name
  );
  return \@keys;
}

=item item_keys()

Returns all keys the item hashes returned by any child's C<items()> method must
contain. If you add keys to this list, you need to add them to all classes
inheriting from C<SL::XMLInvoice> as well. An application may use this method
to discover the metadata keys guaranteed to be present.

=back

=cut

sub item_keys  {
  my @keys = (
    'currency',
    'description',
    'price',
    'quantity',
    'subtotal',
    'tax_rate',
    'tax_scheme',
    'vendor_partno',
  );
  return \@keys;
}

=head2 User/application facing methods

Any class inheriting from C<SL::XMLInvoice> must implement the following
methods. To ensure this happens, C<SL::XMLInvoice> contains stub functions that
raise an exception if a child class does not override them.

=over 4

=item new($xml_data)

Constructor for C<SL::XMLInvoice>. This method takes a scalar containing the
entire XML document to be parsed as a flat string as its sole argument. It will
instantiate the appropriate child class to parse the XML document in question,
call its C<parse_xml> method and return the C<SL::XMLInvoice> child object it
instantiated. From that point on, the structured data retrieved from the XML
document will be available through the object's C<metadata> and C<items()>
methods.

=item metadata()

This method returns a hash of document level metadata, such as the invoice
number, the total, or the the issuance date. Its keys are the keys returned by
the C<(data_keys()> method. Its values are plain scalars containing strings or
C<undef> for any data items not present or empty in the XML document.

=cut

sub metadata {
  my $self = shift;
  die "Children of $self must implement a metadata() method returning the bill's metadata as a hash.";
}

=item items()

This method returns an array of hashes containing line item metadata, such as
the quantity, price for one unit, or subtotal. These hashes' keys are the keys
returned by the C<(item_keys()> method. Its values are plain scalars containing
strings or C<undef> for any data items not present or empty in the XML
document.

=cut

sub items {
  my $self = shift;
  die "Children of $self must implement a item() method returning the bill's items as a hash.";
}

=item parse_xml()

This method is only implemented in child classes of C<SL::XMLInvoice> and is
called by the C<SL::XMLInvoice> constructor once the appropriate child class has been
determined and instantiated. It uses C<$self->{dom}>, an C<XML::LibXML>
instance to iterate through the XML document to parse. That XML document is
created by the C<SL::XMLInvoice> constructor.

=back

=cut

sub parse_xml {
  my $self = shift;
  die "Children of $self must implement a parse_xml() method.";
}

=head2 Internal methods

These methods' purpose is child classs selection and making sure child classes
implent the interface promised by C<SL::XMLInvoice>. You can safely ignore them
if you don't plan on implementing any child classes.

=over 4

=item _document_nodenames()

This method is implemented in C<SL::XMLInvoice> only and returns a hash mapping
XML document root node name to a child class implementing a parser for it. If
you add any child classes for new XML document types you need to add them to
this hash and add a use statement to make it available from C<SL::XMLInvoice>.

=cut

sub _document_nodenames {
  return {
    'rsm:CrossIndustryInvoice' => 'SL::XMLInvoice::CrossIndustryInvoice',
    'ubl:Invoice' => 'SL::XMLInvoice::UBL',
  };
}

=item _data_keys()

Returns a list of all keys present in the hash returned by the class'
C<metadata()> method. Must be implemented in all classes inheriting from
C<SL::XMLInvoice> This list must contain the same keys as the list returned by
C<data_keys>. Omitting this method from a child class will cause an exception.

=cut

sub _data_keys {
  my $self = shift;
  die "Children of $self must implement a _data_keys() method returning the keys an invoice item hash will contain.";
}

=item _item_keys()

Returns a list of all keys present in the hashes returned by the class'
C<items()> method. Must be implemented in all classes inheriting from
C<SL::XMLInvoice> This list must contain the same keys as the list returned by
C<item_keys>. Omitting this method from a child class will cause an exception.

=back

=head1 AUTHOR

  Johannes Grassler <info@computer-grassler.de>

=cut

sub _item_keys {
  my $self = shift;
  die "Children of $self must implement a _item_keys() method returning the keys an invoice item hash will contain.";
}


sub new {
  my ($self, $xml_data) = @_;
  my $type = undef;
  $self = {};

  bless $self;

  $self->{message} = '';
  $self->{dom} = eval { XML::LibXML->load_xml(string => $xml_data) };

  if ( ! $self->{dom} ) {
    $self->{message} = t8("Parsing the XML data failed: #1", $xml_data);
    $self->{result} = RES_XML_PARSING_FAILED;
    return $self;
  }

  # Determine parser class to use
  my $document_nodename = $self->{dom}->documentElement->nodeName;
  if ( ${$self->_document_nodenames}{$document_nodename} ) {
    $type = ${$self->_document_nodenames}{$document_nodename}
  }

  unless ( $type ) {
    $self->{result} = RES_UNKNOWN_ROOT_NODE_TYPE;
    my $node_types = join(",", keys %{ $self->_document_nodenames });
    $self->{message} =  t8("Could not parse XML Invoice: unknown root node name (#1) (supported: (#2))",
                           $document_nodename,
                           $node_types,
                        );
    return $self;
  }

  eval {require $type}; # Load the parser class
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

