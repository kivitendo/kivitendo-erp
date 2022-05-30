package SL::DB::Manager::ValidityToken;

use strict;

use parent qw(SL::DB::Helper::Manager);

sub object_class { 'SL::DB::ValidityToken' }

use Carp;

__PACKAGE__->make_manager_methods;

sub cleanup {
  my ($class) = @_;
  $class->delete_all(where => [ valid_until => { lt => DateTime->now_local }]);
}

sub fetch_valid_token {
  my ($class, %params) = @_;

  croak "missing required parameter 'scope'" if !$params{scope};

  return undef if !$params{token};

  my $token_obj = $class->get_first(
    where => [
      scope       => $params{scope},
      token       => $params{token},
      valid_until => { ge => DateTime->now_local },
    ]);

  return $token_obj;
}

1;
