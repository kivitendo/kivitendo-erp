package SL::Controller::SalesPurchase;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::PurchaseInvoice;
use Carp;


sub action_check_duplicate_invnumber {
  my ($self) = @_;

  croak("no invnumber") unless $::form->{invnumber};
  croak("no vendor")    unless $::form->{vendor_id};

  # Changing an already booked invoice:
  # Check for duplicate invnumber for that vendor only if vendor or invnumber are changed.
  my $should_check = 1;
  if ($::form->{id}) {
    my $invoice   = SL::DB::PurchaseInvoice->new(id => $::form->{id})->load;
    $should_check = $invoice->invnumber ne $::form->{invnumber} || $invoice->vendor_id ne $::form->{vendor_id};
  }

  my $exists_ap;
  if ($should_check) {
    $exists_ap = SL::DB::Manager::PurchaseInvoice->find_by(
                  invnumber => $::form->{invnumber},
                  vendor_id => $::form->{vendor_id},
               );
  }

  $_[0]->render(\ !!$exists_ap, { type => 'text' });
}

1;

=pod

=encoding utf8

=head1 NAME

SL::Controller::SalesPurchase - Controller for JS driven actions

=head2 OVERVIEW

Generic Controller Class for validation function

=head1 FUNCTIONS

=over 2

=item C<action_check_duplicate_invnumber>

Needs C<form.invnumber> and C<form.vendor_id>.
Optional can use C<form.id>.

Returns true if a credit record with this invnumber for this vendor
already exists.
If an id is given, only check for a duplicate invnumber, if for
an exisiting record the vendor or the invnumber has changed.

Example usage (js):

 $.ajax({
      url: 'controller.pl',
      data: { action: 'SalesPurchase/check_duplicate_invnumber',
              vendor_id    : $('#vendor_id').val(),
              invnumber    : $('#invnumber').val(),
              id           : $('#id').val(),
      },
      method: "GET",
      async: false,
      dataType: 'text',
      success: function(val) {
        exists_invnumber = val;
      }
    });

=back
