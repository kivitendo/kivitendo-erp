package SL::Controller::SalesPurchase;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::PurchaseInvoice;
use Carp;


sub action_check_duplicate_invnumber {
  my ($self) = @_;

  croak("no invnumber") unless $::form->{invnumber};
  croak("no vendor")    unless $::form->{vendor_id};

  my $exists_ap = SL::DB::Manager::PurchaseInvoice->find_by(
                   invnumber => $::form->{invnumber},
                   vendor_id => $::form->{vendor_id},
                 );
  # we are modifying a existing daily booking - allow this if
  # booking conditions are not super strict
  undef $exists_ap if ($::instance_conf->get_ap_changeable != 0
                    && $exists_ap->gldate == DateTime->today_local);


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

Needs C<form.invnumber> and C<form.vendor_id>

Returns true if a credit record with this invnumber for this vendor
already exists.

Example usage (js):

 $.ajax({
      url: 'controller.pl',
      data: { action: 'SalesPurchase/check_duplicate_invnumber',
              vendor_id    : $('#vendor_id').val(),
              invnumber    : $('#invnumber').val()
      },
      method: "GET",
      async: false,
      dataType: 'text',
      success: function(val) {
        exists_invnumber = val;
      }
    });

=back
