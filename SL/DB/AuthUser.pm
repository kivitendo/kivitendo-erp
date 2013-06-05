# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::AuthUser;

use strict;

use List::Util qw(first);

use SL::DB::MetaSetup::AuthUser;
use SL::DB::Manager::AuthUser;
use SL::DB::AuthUserGroup;

__PACKAGE__->meta->schema('auth');

__PACKAGE__->meta->add_relationship(
  groups => {
    type      => 'many to many',
    map_class => 'SL::DB::AuthUserGroup',
    map_from  => 'user',
    map_to    => 'group',
  },
  configs => {
    type       => 'one to many',
    class      => 'SL::DB::AuthUserConfig',
    column_map => { id => 'user_id' },
  },
  clients => {
    type      => 'many to many',
    map_class => 'SL::DB::AuthClient',
    map_from  => 'user',
    map_to    => 'client',
  },
);

__PACKAGE__->meta->initialize;

sub get_config_value {
  my ($self, $key) = @_;

  my $cfg = first { $_->cfg_key eq $key } @{ $self->configs };
  return $cfg ? $cfg->cfg_value : undef;
}

sub config_values {
  my $self = shift;

  if (0 != scalar(@_)) {
    my %settings = (ref($_[0]) || '') eq 'HASH' ? %{ $_[0] } : @_;
    $self->configs([ map { SL::DB::AuthUserConfig->new(cfg_key => $_, cfg_value => $settings{$_}) } keys %settings ]);
  }

  return { map { ($_->cfg_key => $_->cfg_value) } @{ $self->configs } };
}

1;
