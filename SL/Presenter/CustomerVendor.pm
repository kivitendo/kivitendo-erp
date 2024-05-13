package SL::Presenter::CustomerVendor;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag html_tag name_to_id select_tag link_tag img_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(customer_vendor customer vendor customer_vendor_picker customer_picker vendor_picker);

use Carp;

sub customer_vendor {
  my ($customer_vendor, %params) = @_;
  return _customer_vendor($customer_vendor, ref($customer_vendor) eq 'SL::DB::Customer' ? 'customer' : 'vendor', %params);
}

sub customer {
  my ($customer, %params) = @_;
  return _customer_vendor($customer, 'customer', %params);
}

sub vendor {
  my ($vendor, %params) = @_;
  return _customer_vendor($vendor, 'vendor', %params);
}

sub _customer_vendor {
  my ($cv, $type, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = escape($cv->name);
  if (! delete $params{no_link}) {
    my $href = 'controller.pl?action=CustomerVendor/edit&db=' . $type
               . '&id=' . escape($cv->id);
    $text = link_tag($href, $text, %params);
  }

  is_escaped($text);
}

sub customer_vendor_picker {
  my ($name, $value, %params) = @_;

  $params{type} //= 'customer' if 'SL::DB::Customer' eq ref $value;
  $params{type} //= 'vendor'   if 'SL::DB::Vendor'   eq ref $value;

  croak 'Unknown "type" parameter' unless $params{type} =~ m{^(?:customer|vendor)$};
  croak 'Unknown value class'      if     $value && ref($value) && (ref($value) !~ m{^SL::DB::(?:Customer|Vendor)$});

  if ($value && !ref $value) {
    my $class = $params{type} eq 'customer' ? 'SL::DB::Manager::Customer' : 'SL::DB::Manager::Vendor';
    $value    = $class->find_by(id => $value);
  }

  my $id = delete($params{id}) || name_to_id($name);

  my @classes = $params{class} ? ($params{class}) : ();
  push @classes, 'customer_vendor_autocomplete';

  # do not use reserved html attribute 'type' for cv type
  $params{cv_type} = delete $params{type};

  my $show_details = delete $params{show_details} // 0;

  # If there is no 'onClick' parameter, set it to 'this.select()',
  # so that the user can type directly in the input field
  # to search another customer/vendor.
  if (!grep { m{onclick}i } keys %params) {
    $params{onClick} = 'this.select()';
  }

  my $ret =
    input_tag($name, (ref $value && $value->can('id') ? $value->id : ''), class => "@classes", type => 'hidden', id => $id,
      'data-customer-vendor-picker-data' => JSON::to_json(\%params),
    ) .
    input_tag("", ref $value  ? $value->displayable_name : '', id => "${id}_name", %params);

  if ($show_details) {
    $ret .= img_tag(src => 'image/detail.png', alt => $::locale->text('Show details'),
      title => $::locale->text('Show details'), class => "button-image info",
      onclick => "kivi.CustomerVendor.show_cv_details_dialog('#${id}', '$params{cv_type}')" );

    $ret .= link_tag('javascript:;', $::locale->text('Edit'),
      title => $::locale->text('Open in new window'),
      onclick => "kivi.CustomerVendor.open_customervendor_tab('#${id}', '$params{cv_type}')" );
  }

  $::request->layout->add_javascripts('kivi.CustomerVendor.js');
  $::request->presenter->need_reinit_widgets($id);

  html_tag('span', $ret, class => 'customer_vendor_picker');
}

sub customer_picker { my ($name, $value, @slurp) = @_; customer_vendor_picker($name, $value, @slurp, type => 'customer') }
sub vendor_picker   { my ($name, $value, @slurp) = @_; customer_vendor_picker($name, $value, @slurp, type => 'vendor') }
sub picker          { goto &customer_vendor_picker }

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::CustomerVendor - Presenter module for customer and
vendor Rose::DB objects

=head1 SYNOPSIS

  # Customers:
  my $customer = SL::DB::Manager::Customer->get_first;
  my $html     = SL::Presenter::CustomerVendor::customer($customer, display => 'inline');

  # Vendors:
  my $vendor = SL::DB::Manager::Vendor->get_first;
  my $html   = SL::Presenter::Customer::Vendor::vendor($customer, display => 'inline');

=head1 FUNCTIONS

=over 4

=item C<customer $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the customer object C<$object>.

Remaining C<%params> are passed to the function
C<SL::Presenter::Tag::link_tag>. It can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. Is passed to the function
C<SL::Presenter::Tag::link_tag>.

=item * no_link

If falsish (the default) then the customer's name will be linked to
the "edit customer" dialog from the master data menu.

=back

=item C<vendor $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the vendor object C<$object>.

Remaining C<%params> are passed to the function
C<SL::Presenter::Tag::link_tag>. It can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. Is passed to the function
C<SL::Presenter::Tag::link_tag>.

=item * no_link

If falsish (the default) then the vendor's name will be linked to
the "edit vendor" dialog from the master data menu.

=back

=item C<customer_vendor $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the customer or vendor object
C<$object> by calling either L</customer> or L</vendor> depending on
C<$object>'s type. See the respective functions for available
parameters.

=back

=over 4

=item C<customer_vendor_picker $name, $value, %params>

Renders a customer/vendor picker. The name will be both id and name
of the resulting hidden C<id> input field (but the ID can be
overwritten with C<$params{id}>).

An additional dummy input field is rendered that will contain the
customer/vendor's name.

C<$value> can be a customer/vendor ID or a C<Rose::DB:Object> instance.
If it is an instance then the type will be determined automatically.

However the type, C<customer> or C<vendor>, can also be specified using
C<$type>.

On top of that there are wrapper functions C<customer_picker> and
C<vendor_picker> that set the type automatically.

If C<$show_details> is true then the picker will be rendered with an
additional button to open the customer/vendor details dialog and a
link to open the customer/vendor in a new tab. This can be used in the
record views as well as in account receivable/payable.

=back

=head1 TESTS

For the pickers see Developer tools -> Customer/Vendor Test.

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
