package SL::Presenter::CustomerVendor;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(customer_vendor customer vendor customer_vendor_picker);

use Carp;

sub customer_vendor {
  my ($self, $customer_vendor, %params) = @_;
  return _customer_vendor($self, $customer_vendor, ref($customer_vendor) eq 'SL::DB::Customer' ? 'customer' : 'vendor', %params);
}

sub customer {
  my ($self, $customer, %params) = @_;
  return _customer_vendor($self, $customer, 'customer', %params);
}

sub vendor {
  my ($self, $vendor, %params) = @_;
  return _customer_vendor($self, $vendor, 'vendor', %params);
}

sub _customer_vendor {
  my ($self, $cv, $type, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $callback = $params{callback} ? '&callback=' . $::form->escape($params{callback}) : '';

  my $text = join '', (
    $params{no_link} ? '' : '<a href="controller.pl?action=CustomerVendor/edit&amp;db=' . $type . '&amp;id=' . $self->escape($cv->id) . '">',
    $self->escape($cv->name),
    $params{no_link} ? '' : '</a>',
  );
  return $self->escaped_text($text);
}

sub customer_vendor_picker {
  my ($self, $name, $value, %params) = @_;

  croak 'Unknown "type" parameter' unless $params{type} =~ m{^(?:customer|vendor)$};
  croak 'Unknown value class'      if     $value && ref($value) && (ref($value) !~ m{^SL::DB::(?:Customer|Vendor)$});

  if ($value && !ref $value) {
    my $class = $params{type} eq 'customer' ? 'SL::DB::Manager::Customer' : 'SL::DB::Manager::Vendor';
    $value    = $class->find_by(id => $value);
  }

  my $id = delete($params{id}) || $self->name_to_id($name);
  my $fat_set_item = delete $params{fat_set_item};

  my @classes = $params{class} ? ($params{class}) : ();
  push @classes, 'customer_vendor_autocomplete';
  push @classes, 'customer-vendor-picker-fat-set-item' if $fat_set_item;

  my $ret =
    $self->input_tag($name, (ref $value && $value->can('id') ? $value->id : ''), class => "@classes", type => 'hidden', id => $id) .
    join('', map { $params{$_} ? $self->input_tag("", delete $params{$_}, id => "${id}_${_}", type => 'hidden') : '' } qw(type)) .
    $self->input_tag("", ref $value  ? $value->displayable_name : '', id => "${id}_name", %params);

  $::request->layout->add_javascripts('autocomplete_customer.js');
  $::request->presenter->need_reinit_widgets($id);

  $self->html_tag('span', $ret, class => 'customer_vendor_picker');
}

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
  my $html     = SL::Presenter->get->customer($customer, display => 'inline');

  # Vendors:
  my $vendor = SL::DB::Manager::Vendor->get_first;
  my $html   = SL::Presenter->get->vendor($customer, display => 'inline');

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
