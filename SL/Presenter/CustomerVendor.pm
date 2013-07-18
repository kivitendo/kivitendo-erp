package SL::Presenter::CustomerVendor;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(customer vendor);

use Carp;

sub customer {
  my ($self, $customer, $type, %params) = @_;
  return _customer_vendor($self, $customer, 'customer', %params);
}

sub vendor {
  my ($self, $vendor, $type, %params) = @_;
  return _customer_vendor($self, $vendor, 'vendor', %params);
}

sub _customer_vendor {
  my ($self, $cv, $type, %params) = @_;

  $params{display} ||= 'inline';

  croak "Unknown display type '$params{display}'" unless $params{display} =~ m/^(?:inline|table-cell)$/;

  my $text = join '', (
    $params{no_link} ? '' : '<a href="controller.pl?action=CustomerVendor/edit&amp;db=' . $type . '&amp;id=' . $self->escape($cv->id) . '">',
    $self->escape($cv->name),
    $params{no_link} ? '' : '</a>',
  );
  return $self->escaped_text($text);
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

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
