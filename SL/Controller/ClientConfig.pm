package SL::Controller::ClientConfig;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::Default;
use SL::Helper::Flash;

__PACKAGE__->run_before('check_auth');


sub action_edit {
  my ($self, %params) = @_;

  $self->{payment_options} = [ { title => $::locale->text("never"), value => 0 },
                               { title => $::locale->text("every time"), value => 1 },
                               { title => $::locale->text("on the same day"), value => 2 }, ];

  $self->{payments_changeable} = SL::DB::Default->get->payments_changeable;

  $self->render('client_config/form', title => $::locale->text('Client Configuration'));
}


sub action_save {
  my ($self, %params) = @_;

  SL::DB::Default->get->update_attributes('payments_changeable' => $::form->{payments_changeable});

  flash_later('info', $::locale->text('Client Configuration saved!'));

  $self->redirect_to(action => 'edit');
}


#################### private stuff ##########################

sub check_auth {
  $::auth->assert('admin');
}

1;
