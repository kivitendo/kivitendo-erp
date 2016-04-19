# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::PeriodicInvoicesConfig;

use strict;

use parent qw(SL::DB::Object);

__PACKAGE__->meta->table('periodic_invoices_configs');

__PACKAGE__->meta->columns(
  active                     => { type => 'boolean', default => 'true' },
  ar_chart_id                => { type => 'integer', not_null => 1 },
  copies                     => { type => 'integer' },
  direct_debit               => { type => 'boolean', default => 'false', not_null => 1 },
  email_body                 => { type => 'text' },
  email_recipient_address    => { type => 'text' },
  email_recipient_contact_id => { type => 'integer' },
  email_sender               => { type => 'text' },
  email_subject              => { type => 'text' },
  end_date                   => { type => 'date' },
  extend_automatically_by    => { type => 'integer' },
  first_billing_date         => { type => 'date' },
  id                         => { type => 'integer', not_null => 1, sequence => 'id' },
  oe_id                      => { type => 'integer', not_null => 1 },
  order_value_periodicity    => { type => 'varchar', length => 1, not_null => 1 },
  periodicity                => { type => 'varchar', length => 1, not_null => 1 },
  print                      => { type => 'boolean', default => 'false' },
  printer_id                 => { type => 'integer' },
  send_email                 => { type => 'boolean', default => 'false', not_null => 1 },
  start_date                 => { type => 'date' },
  terminated                 => { type => 'boolean', default => 'false' },
);

__PACKAGE__->meta->primary_key_columns([ 'id' ]);

__PACKAGE__->meta->foreign_keys(
  ar_chart => {
    class       => 'SL::DB::Chart',
    key_columns => { ar_chart_id => 'id' },
  },

  email_recipient_contact => {
    class       => 'SL::DB::Contact',
    key_columns => { email_recipient_contact_id => 'cp_id' },
  },

  order => {
    class       => 'SL::DB::Order',
    key_columns => { oe_id => 'id' },
  },

  printer => {
    class       => 'SL::DB::Printer',
    key_columns => { printer_id => 'id' },
  },
);

1;
;
