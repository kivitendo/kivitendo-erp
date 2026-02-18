package SL::SearchProfileManager;

use strict;
use warnings;
use utf8;

use parent qw(Rose::Object);

use Carp;
use SL::DB::Employee;
use SL::DB::SearchProfile;
use SL::DB::SearchProfileSetting;
use Params::Validate qw(:all);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(config defaults module employee_id) ],
);

sub init_config {
  croak "caller must initialize config before usage";
}

sub init_defaults {
  return {};
}

sub init_employee_id {
  my ($self) = @_;

  return SL::DB::Manager::Employee->current->id
}

sub map_value_types_by_field {
  my ($self) = @_;

  my %value_types_by_field = map {
    my $entry = $_;
    map { ($_ => $entry->{type}) } @{ $entry->{fields} }
  } @{ $self->config };

  return %value_types_by_field;
}

sub save_profile {
  my $self = shift;

  my %params = validate(@_, {
    name            => 1,
    form            => { type => HASHREF },
    default_profile => { default => 0, optional => 1 },
  });

  my $profile = SL::DB::Manager::SearchProfile->get_first(
    where => [
      module      => $self->module,
      employee_id => $self->employee_id,
      name        => $params{name},
    ]);

  if (!$profile) {
    $profile = SL::DB::SearchProfile->new(
      module          => $self->module,
      employee_id     => $self->employee_id,
      name            => $params{name},
      default_profile => $params{default_profile} ? 1 : 0,
    );
  }

  my %types_by_field = $self->map_value_types_by_field;
  my @settings;

  foreach my $key (keys %{ $params{form} }) {
    my $type = $types_by_field{$key};
    next unless $type;

    push @settings, SL::DB::SearchProfileSetting->new(
      name => $key,
      type => $type,
    );

    # `type` must be set before `parsed_value` can be called; therefore do it after `new`
    $settings[-1]->parsed_value($params{form}->{$key});
  }

  $profile->search_profile_settings(\@settings);

  $profile->save;

  if ($params{default_profile}) {
    SL::DB::Manager::SearchProfile->update_all(
      set   => { default_profile => 0 },
      where => [
        module          => $self->module,
        employee_id     => $self->employee_id,
        default_profile => 1,
        '!id'           => $profile->id,
      ],
    );
  }

  return $profile;
}

sub load_profile {
  my $self   = shift;
  my %params = validate(@_, {
    profile => { type => OBJECT | UNDEF, optional => 1 },
    form    => { type => HASHREF },
  });

  my %types_by_field = $self->map_value_types_by_field;

  foreach my $key (keys %{ $self->defaults }) {
    $params{form}->{$key} = $self->defaults->{$key};
  }

  return if !$params{profile};

  foreach my $setting (@{ $params{profile}->search_profile_settings }) {
    $params{form}->{$setting->name} = $setting->parsed_value;
  }
}

sub delete_profile {
  my $self   = shift;
  my %params = validate(@_, {
    profile_id => { type => SCALAR },
  });

  SL::DB::Manager::SearchProfile->delete_all(
    where => [
      module      => $self->module,
      employee_id => $self->employee_id,
      id          => $params{profile_id},
    ],
    cascade => 1,
  );
}

sub get_all_profiles {
  my ($self, %params) = @_;

  return scalar SL::DB::Manager::SearchProfile->get_all_sorted(
    where => [
      @{ $params{where} // [] },
      employee_id => $self->employee_id,
      module      => $self->module,
    ]);
}

sub get_default_profile {
  my ($self) = @_;

  return SL::DB::Manager::SearchProfile->get_first(
    where => [
      module          => $self->module,
      employee_id     => $self->employee_id,
      default_profile => 1,
    ]);
}

1;
