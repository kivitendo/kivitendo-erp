package SL::DB::SearchProfile;

use strict;

use SL::DB::MetaSetup::SearchProfile;
use SL::DB::Manager::SearchProfile;
use SL::Locale::String qw(t8);

__PACKAGE__->meta->add_relationship(
  search_profile_settings => {
    type       => 'one to many',
    class      => 'SL::DB::SearchProfileSetting',
    column_map => { id => 'search_profile_id' },
  },
);

__PACKAGE__->meta->initialize;

sub displayable_name {
  my ($self) = @_;

  my $name = $self->name // '';
  $name   .= ' (' . t8('default profile') . ')' if $self->default_profile;

  return $name;
}

1;
