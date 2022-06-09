package SL::DB::ValidityToken;

use strict;

use Carp;
use Digest::SHA qw(sha256_hex);
use Time::HiRes qw(gettimeofday);

use SL::DB::MetaSetup::ValidityToken;
use SL::DB::Manager::ValidityToken;

__PACKAGE__->meta->initialize;

use constant SCOPE_SALES_INVOICE_POST => 'SalesInvoice::Post';

sub create {
  my ($class, %params) = @_;

  croak "missing required parameter 'scope'" if !$params{scope};

  my $token_obj = $class->new(
    scope       => $params{scope},
    valid_until => $params{valid_until} // DateTime->now_local->add(hours => 24),
  );

  while (1) {
    my $token_value = join('-', gettimeofday(), $$, int(rand(1 << 63)));

    $token_obj->token(sha256_hex($token_value));

    last if eval {
      $token_obj->save;
      1;
    };
  }

  return $token_obj;
}


1;
