# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::OAuthToken;

use strict;

use SL::DB::MetaSetup::OAuthToken;
use SL::DB::Manager::Employee;
use SL::DB::Manager::OAuthToken;

__PACKAGE__->meta->initialize;

sub set_access_refresh_token {
  my ($self, $content) = @_;

  my $expiration = DateTime->now;
  $expiration->add(seconds => $content->{expires_in});

  $self->access_token_expiration($expiration);
  $self->$_($content->{$_}) for qw(access_token scope);
  $self->refresh_token($content->{refresh_token}) if exists $content->{refresh_token};
}

sub is_valid {
  my ($self) = @_;

  my $exp = $self->access_token_expiration;
  my $now = DateTime->now;
  return $exp > $now;
}

sub is_editable {
  my ($self) = @_;

  ($self->employee_id == SL::DB::Manager::Employee->current->id) || $::auth->assert('admin', 'may_fail');
}

1;
