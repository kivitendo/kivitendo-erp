package SL::Controller::ClientConfig;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::Default;
use SL::Helper::Flash;

__PACKAGE__->run_before('check_auth');


sub action_edit {
  my ($self, %params) = @_;

  $self->{posting_options} = [ { title => $::locale->text("never"), value => 0 },
                               { title => $::locale->text("every time"), value => 1 },
                               { title => $::locale->text("on the same day"), value => 2 }, ];
  $self->{payment_options} = [ { title => $::locale->text("never"), value => 0 },
                               { title => $::locale->text("every time"), value => 1 },
                               { title => $::locale->text("on the same day"), value => 2 }, ];
  $self->{accounting_options} = [ { title => $::locale->text("Accrual"), value => "accrual" },
                                  { title => $::locale->text("cash"), value => "cash" }, ];
  $self->{inventory_options} = [ { title => $::locale->text("perpetual"), value => "perpetual" },
                                 { title => $::locale->text("periodic"), value => "periodic" }, ];
  $self->{profit_options} = [ { title => $::locale->text("balance"), value => "balance" },
                              { title => $::locale->text("income"), value => "income" }, ];

  map { $self->{$_} = SL::DB::Default->get->$_ } qw(is_changeable ir_changeable ar_changeable ap_changeable gl_changeable);

  $self->{payments_changeable} = SL::DB::Default->get->payments_changeable;

  map { $self->{$_} = SL::DB::Default->get->$_ } qw(is_show_mark_as_paid ir_show_mark_as_paid ar_show_mark_as_paid ap_show_mark_as_paid);

  map { $self->{$_} = SL::DB::Default->get->$_ } qw(accounting_method inventory_system profit_determination);

  $self->{show_bestbefore}     = SL::DB::Default->get->show_bestbefore;

  map { $self->{$_} = SL::DB::Default->get->$_ } qw(datev_check_on_sales_invoice datev_check_on_purchase_invoice datev_check_on_ar_transaction datev_check_on_ap_transaction datev_check_on_gl_transaction);
  # datev check: not implemented yet:
  #check_on_cash_and_receipt = 0
  #check_on_dunning = 0
  #check_on_sepa_import = 0

  map { $self->{$_} = SL::DB::Default->get->$_ } qw(sales_order_show_delete purchase_order_show_delete sales_delivery_order_show_delete purchase_delivery_order_show_delete);

  map { $self->{$_} = SL::DB::Default->get->$_ } qw(warehouse_id bin_id);
  $::form->get_lists('warehouses' => { 'key'    => 'WAREHOUSES',
                                       'bins'   => 'BINS', });
  $self->{WAREHOUSES} = $::form->{WAREHOUSES};
  # leerer lagerplatz mit id 0
  my $no_default_bin_entry = { 'id' => '0', description => '--', 'BINS' => [ { id => '0', description => ''} ] };
  push @ { $self->{WAREHOUSES} }, $no_default_bin_entry;

  if (my $max = scalar @{ $self->{WAREHOUSES} }) {
    $self->{warehouse_id} ||= $self->{WAREHOUSES}->[$max -1]->{id};
    $self->{bin_id}       ||= $self->{WAREHOUSES}->[$max -1]->{BINS}->[0]->{id};
  }

  $self->{show_weight} = SL::DB::Default->get->show_weight;

  $self->render('client_config/form', title => $::locale->text('Client Configuration'));
}


sub action_save {
  my ($self, %params) = @_;

  map { SL::DB::Default->get->update_attributes($_ => $::form->{$_}); } qw(is_changeable ir_changeable ar_changeable ap_changeable gl_changeable);

  SL::DB::Default->get->update_attributes('payments_changeable' => $::form->{payments_changeable});

  map { SL::DB::Default->get->update_attributes($_ => $::form->{$_}); } qw(is_show_mark_as_paid ir_show_mark_as_paid ar_show_mark_as_paid ap_show_mark_as_paid);

  map { SL::DB::Default->get->update_attributes($_ => $::form->{$_}); } qw(accounting_method inventory_system profit_determination);

  SL::DB::Default->get->update_attributes('show_bestbefore'     => $::form->{show_bestbefore});

  map { SL::DB::Default->get->update_attributes($_ => $::form->{$_}); } qw(datev_check_on_sales_invoice datev_check_on_purchase_invoice datev_check_on_ar_transaction datev_check_on_ap_transaction datev_check_on_gl_transaction);

  map { SL::DB::Default->get->update_attributes($_ => $::form->{$_}); } qw(sales_order_show_delete purchase_order_show_delete sales_delivery_order_show_delete purchase_delivery_order_show_delete);

  # undef warehouse_id if the empty value is selected
  if ( ($::form->{warehouse_id} == 0) && ($::form->{bin_id} == 0) ) {
    undef $::form->{warehouse_id};
    undef $::form->{bin_id};
  }
  map { SL::DB::Default->get->update_attributes($_ => $::form->{$_}); } qw(warehouse_id bin_id);

  SL::DB::Default->get->update_attributes('show_weight'     => $::form->{show_weight});

  flash_later('info', $::locale->text('Client Configuration saved!'));

  $self->redirect_to(action => 'edit');
}


#################### private stuff ##########################

sub check_auth {
  $::auth->assert('admin');
}

1;
