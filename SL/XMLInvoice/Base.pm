package SL::XMLInvoice::Base;

use strict;
use warnings;

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

=item check_signature($dom)

This static method takes a DOM object and returns 1 if this DOM object can be
parsed by the child class in question, 0 otherwise. C<SL::XMLInvoice> uses this
method to determine which child class to instantiate for a given document. All
child classes must implement this method.

=cut

sub check_signature {
  my $self = shift;
  die "Children of $self must implement a check_signature() method returning 1 for supported XML, 0 for unsupported XML.";
}

=item supported()

This static method returns an array of free-form strings describing XML invoice
types parseable by the child class. C<SL::XMLInvoice> uses this method to
output a list of supported XML invoice types if its constructor fails to find
to find an appropriate child class to parse the given document with. All child
classes must implement this method.

=cut

sub supported {
  my $self = shift;
  die "Children of $self must implement a supported() method returning a list of supported XML invoice types.";
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
implent the interface promised by C<SL::XMLInvoice::Base>. You can safely ignore them
if you don't plan on implementing any child classes.

=over 4

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



1;
