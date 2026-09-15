# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::OAuthToken;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('oauth_token');

__PACKAGE__->meta->columns(
  access_token            => { type => 'text' },
  access_token_expiration => { type => 'timestamp' },
  email                   => { type => 'text' },
  employee_id             => { type => 'integer' },
  id                      => { type => 'serial', not_null => 1 },
  itime                   => { type => 'timestamp', default => 'now()', not_null => 1 },
  mtime                   => { type => 'timestamp', default => 'now()', not_null => 1 },
  refresh_token           => { type => 'text' },
  registration            => { type => 'text', not_null => 1 },
  scope                   => { type => 'text' },
  tokenstate              => { type => 'text' },
  verifier                => { type => 'text' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->allow_inline_column_values(1);

__PACKAGE__->meta->foreign_keys(
  employee => {
    class       => 'SL::DB::Employee',
    key_columns => { employee_id => 'id' },
  },
);

1;
;
