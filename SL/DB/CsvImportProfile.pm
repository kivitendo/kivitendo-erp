package SL::DB::CsvImportProfile;

use strict;

use List::Util qw(first);

require SL::DB::MetaSetup::CsvImportProfile;

__PACKAGE__->meta->add_relationship(
  settings => {
    type       => 'one to many',
    class      => 'SL::DB::CsvImportProfileSetting',
    column_map => { id      => 'csv_import_profile_id' },
  },
);

__PACKAGE__->meta->initialize;

__PACKAGE__->meta->make_manager_class;

__PACKAGE__->before_save('_before_save_unset_default_on_others');

#
# public functions
#

sub new_with_default {
  my ($class, $type) = @_;

  return $class->new(type => $type)->set_defaults;
}

sub set_defaults {
  my ($self) = @_;

  $self->_set_defaults(sep_char     => ',',
                       quote_char   => '"',
                       escape_char  => '"',
                       charset      => 'CP850',
                       numberformat => $::myconfig{numberformat},
                       dateformat   => $::myconfig{dateformat},
                       duplicates   => 'no_check',
                      );

  return $self;
}

sub set {
  my ($self, %params) = @_;

  while (my ($key, $value) = each %params) {
    my $setting = $self->_get_setting($key);

    if (!$setting) {
      $setting = SL::DB::CsvImportProfileSetting->new(key => $key);
      $self->settings(@{ $self->settings || [] }, $setting);
    }

    $setting->value($value);
  }

  return $self;
}

sub get {
  my ($self, $key, $default) = @_;

  my $setting = $self->_get_setting($key);
  return $setting ? $setting->value : $default;
}

sub _set_defaults {
  my ($self, %params) = @_;

  while (my ($key, $value) = each %params) {
    $self->settings(@{ $self->settings || [] }, { key => $key, value => $value }) if !$self->_get_setting($key);
  }

  return $self;
}

sub clone_and_reset_deep {
  my ($self) = @_;

  my $clone = $self->clone_and_reset;
  $clone->settings(map { $_->clone_and_reset } $self->settings);
  $clone->is_default(0);
  $clone->name('');
  return $clone;
}

sub flatten {
  my ($self) = @_;

  return map {
    $_->key => $_->value
  } $self->settings;
}

#
# hooks
#

sub _before_save_unset_default_on_others {
  my ($self) = @_;

  if ($self->is_default) {
    SL::DB::Manager::CsvImportProfile->update_all(set   => { is_default => 0 },
                                                  where => [ type       => $self->type,
                                                             '!id'      => $self->id ]);
  }

  return 1;
}

#
# helper functions
#

sub _get_setting {
  my ($self, $key) = @_;
  return first { $_->key eq $key } @{ $self->settings || [] };
}

1;
