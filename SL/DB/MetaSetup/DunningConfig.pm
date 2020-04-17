# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::DunningConfig;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('dunning_config');

__PACKAGE__->meta->columns(
  active                   => { type => 'boolean' },
  auto                     => { type => 'boolean' },
  create_invoices_for_fees => { type => 'boolean', default => 'true' },
  dunning_description      => { type => 'text' },
  dunning_level            => { type => 'integer' },
  email                    => { type => 'boolean' },
  email_attachment         => { type => 'boolean' },
  email_body               => { type => 'text' },
  email_subject            => { type => 'text' },
  fee                      => { type => 'numeric', precision => 15, scale => 5 },
  id                       => { type => 'integer', not_null => 1, sequence => 'id' },
  interest_rate            => { type => 'numeric', precision => 15, scale => 5 },
  payment_terms            => { type => 'integer' },
  print_original_invoice   => { type => 'boolean' },
  template                 => { type => 'text' },
  terms                    => { type => 'integer' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

1;
;
