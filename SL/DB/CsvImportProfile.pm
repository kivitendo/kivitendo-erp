package SL::DB::CsvImportProfile;

use strict;

use List::Util qw(first);

use SL::DB::MetaSetup::CsvImportProfile;

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

sub set {
  my ($self, %params) = @_;

  while (my ($key, $value) = each %params) {
    my $setting = $self->_get_setting($key);

    if (!$setting) {
      $setting = SL::DB::CsvImportProfileSetting->new(key => $key);
      $self->add_settings($setting);
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
  return first { $_->key eq $key } @{ $self->settings };
}

1;
