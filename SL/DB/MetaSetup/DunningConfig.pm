# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::DunningConfig;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'dunning_config',

  columns => [
    id                       => { type => 'integer', not_null => 1, sequence => 'id' },
    dunning_level            => { type => 'integer' },
    dunning_description      => { type => 'text' },
    active                   => { type => 'boolean' },
    auto                     => { type => 'boolean' },
    email                    => { type => 'boolean' },
    terms                    => { type => 'integer' },
    payment_terms            => { type => 'integer' },
    fee                      => { type => 'numeric', precision => 5, scale => 15 },
    interest_rate            => { type => 'numeric', precision => 5, scale => 15 },
    email_body               => { type => 'text' },
    email_subject            => { type => 'text' },
    email_attachment         => { type => 'boolean' },
    template                 => { type => 'text' },
    create_invoices_for_fees => { type => 'boolean', default => 'true' },
  ],

  primary_key_columns => [ 'id' ],
);

1;
;
