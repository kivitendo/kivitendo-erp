package SL::Controller::ClientConfig;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::Default;
use SL::Helper::Flash;
use SL::Locale::String qw(t8);

__PACKAGE__->run_before('check_auth');

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(defaults all_warehouses posting_options payment_options accounting_options inventory_options profit_options) ],
);

sub action_edit {
  my ($self, %params) = @_;
  $self->edit_form;
}

sub action_save {
  my ($self, %params) = @_;

  my $defaults = delete($::form->{defaults}) || {};

  # undef several fields if an empty value has been selected.
  foreach (qw(warehouse_id bin_id warehouse_id_ignore_onhand bin_id_ignore_onhand)) {
    undef $defaults->{$_} if !$defaults->{$_};
  }

  $self->defaults->update_attributes(%{ $defaults });

  flash_later('info', t8('Client Configuration saved!'));

  $self->redirect_to(action => 'edit');
}

#
# initializers
#

sub init_defaults       { SL::DB::Default->get }
sub init_all_warehouses { SL::DB::Manager::Warehouse->get_all_sorted }

sub init_posting_options {
  [ { title => t8("never"),           value => 0           },
    { title => t8("every time"),      value => 1           },
    { title => t8("on the same day"), value => 2           }, ]
}

sub init_payment_options {
  [ { title => t8("never"),           value => 0           },
    { title => t8("every time"),      value => 1           },
    { title => t8("on the same day"), value => 2           }, ]
}

sub init_accounting_options {
  [ { title => t8("Accrual"),         value => "accrual"   },
    { title => t8("cash"),            value => "cash"      }, ]
}

sub init_inventory_options {
  [ { title => t8("perpetual"),       value => "perpetual" },
    { title => t8("periodic"),        value => "periodic"  }, ]
}

sub init_profit_options {
  [ { title => t8("balance"),         value => "balance"   },
    { title => t8("income"),          value => "income"    }, ]
}

#
# filters
#

sub check_auth {
  $::auth->assert('admin');
}

#
# helpers
#

sub edit_form {
  my ($self) = @_;
  $self->render('client_config/form', title => t8('Client Configuration'));
}

1;
