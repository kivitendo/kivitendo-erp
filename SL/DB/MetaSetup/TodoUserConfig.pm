# This file has been auto-generated. Do not modify it; it will be overwritten
# by rose_auto_create_model.pl automatically.
package SL::DB::TodoUserConfig;

use strict;

use base qw(SL::DB::Object);

__PACKAGE__->meta->setup(
  table   => 'todo_user_config',

  columns => [
    employee_id                         => { type => 'integer', not_null => 1 },
    show_after_login                    => { type => 'boolean', default => 'true' },
    show_follow_ups                     => { type => 'boolean', default => 'true' },
    show_follow_ups_login               => { type => 'boolean', default => 'true' },
    show_overdue_sales_quotations       => { type => 'boolean', default => 'true' },
    show_overdue_sales_quotations_login => { type => 'boolean', default => 'true' },
    id                                  => { type => 'serial', not_null => 1 },
  ],

  primary_key_columns => [ 'id' ],

  foreign_keys => [
    employee => {
      class       => 'SL::DB::Employee',
      key_columns => { employee_id => 'id' },
    },
  ],
);

1;
;
