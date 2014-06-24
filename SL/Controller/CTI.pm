package SL::Controller::CTI;

use strict;

use SL::CTI;
use SL::DB::AuthUserConfig;
use SL::Helper::Flash;
use SL::Locale::String;

use parent qw(SL::Controller::Base);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(internal_extensions) ],
);

sub action_call {
  my ($self) = @_;

  eval {
    my $res = SL::CTI->call(number => $::form->{number}, internal => $::form->{internal});
    flash('info', t8('Calling #1 now', $::form->{number}));
    1;
  } or do {
    flash('error', $@);
  };

  $self->render('cti/calling');
}

sub action_list_internal_extensions {
  my ($self) = @_;

  $self->render('cti/list_internal_extensions', title => t8('Internal Phone List'));
}

#
# filters
#

sub init_internal_extensions {
  my ($self) = @_;

  my $user_configs = SL::DB::Manager::AuthUserConfig->get_all(
    where => [
      cfg_key      => 'phone_extension',
      '!cfg_value' => undef,
      '!cfg_value' => '',
    ],
    with_objects => [ qw(user) ],
  );

  my %users;
  foreach my $config (@{ $user_configs }) {
    $users{$config->user_id} ||= {
      name            => $config->user->get_config_value('name') || $config->user->login,
      phone_extension => $config->cfg_value,
      call_link       => SL::CTI->call_link(number => $config->cfg_value, internal => 1),
    };
  }

  return [
    sort { lc($a->{name}) cmp lc($b->{name}) } values %users
  ];
}

1;
