package SL::Presenter::CustomerVendor;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(input_tag html_tag name_to_id select_tag);

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

  my $callback = $params{callback} ? '&callback=' . $::form->escape($params{callback}) : '';

  my $text = join '', (
    $params{no_link} ? '' : '<a href="controller.pl?action=CustomerVendor/edit&amp;db=' . $type . '&amp;id=' . escape($cv->id) . '">',
    escape($cv->name),
    $params{no_link} ? '' : '</a>',
  );

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

  my $ret =
    input_tag($name, (ref $value && $value->can('id') ? $value->id : ''), class => "@classes", type => 'hidden', id => $id,
      'data-customer-vendor-picker-data' => JSON::to_json(\%params),
    ) .
    input_tag("", ref $value  ? $value->displayable_name : '', id => "${id}_name", %params);

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

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the customer's name linked
to the corresponding 'edit' action.

=item * no_link

If falsish (the default) then the customer's name will be linked to
the "edit customer" dialog from the master data menu.

=back

=item C<vendor $object, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of the vendor object C<$object>.

C<%params> can include:

=over 2

=item * display

Either C<inline> (the default) or C<table-cell>. At the moment both
representations are identical and produce the vendor's name linked
to the corresponding 'edit' action.

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

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
