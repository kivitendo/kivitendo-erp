# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::Default;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'defaults',

  columns => [
    inventory_accno_id         => { type => 'integer' },
    income_accno_id            => { type => 'integer' },
    expense_accno_id           => { type => 'integer' },
    fxgain_accno_id            => { type => 'integer' },
    fxloss_accno_id            => { type => 'integer' },
    invnumber                  => { type => 'text' },
    sonumber                   => { type => 'text' },
    weightunit                 => { type => 'varchar', length => 5 },
    businessnumber             => { type => 'text' },
    version                    => { type => 'varchar', length => 8 },
    curr                       => { type => 'text' },
    closedto                   => { type => 'date' },
    revtrans                   => { type => 'boolean', default => 'false' },
    ponumber                   => { type => 'text' },
    sqnumber                   => { type => 'text' },
    rfqnumber                  => { type => 'text' },
    customernumber             => { type => 'text' },
    vendornumber               => { type => 'text' },
    audittrail                 => { type => 'boolean', default => 'false' },
    articlenumber              => { type => 'text' },
    servicenumber              => { type => 'text' },
    coa                        => { type => 'text' },
    itime                      => { type => 'timestamp', default => 'now()' },
    mtime                      => { type => 'timestamp' },
    rmanumber                  => { type => 'text' },
    cnnumber                   => { type => 'text' },
    dunning_ar_amount_fee      => { type => 'integer' },
    dunning_ar_amount_interest => { type => 'integer' },
    dunning_ar                 => { type => 'integer' },
    pdonumber                  => { type => 'text' },
    sdonumber                  => { type => 'text' },
    ar_paid_accno_id           => { type => 'integer' },
    id                         => { type => 'serial', not_null => 1 },
    accounting_method          => { type => 'text' },
    inventory_system           => { type => 'text' },
    profit_determination       => { type => 'text' },
  ],

  primary_key_columns => [ 'id' ],

  allow_inline_column_values => 1,
);

1;
;
