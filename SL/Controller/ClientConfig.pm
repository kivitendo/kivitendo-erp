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
  $self->{accounting_options} = [ { title => $::locale->text("accrual"), value => "accrual" },
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

  flash_later('info', $::locale->text('Client Configuration saved!'));

  $self->redirect_to(action => 'edit');
}


#################### private stuff ##########################

sub check_auth {
  $::auth->assert('admin');
}

1;
