# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::AsyncEvent;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DBUtils;

sub object_class { 'SL::DB::AsyncEvent' }

__PACKAGE__->make_manager_methods;

sub cleanup {
  my $dbh = $::form->get_standard_dbh;

  my $timeout          = 60 * 24 * 14; # 14 days
  my $timeout_redacted = 60 * 8;       #  8 hours

  $dbh->do(qq|DELETE FROM async_events
              WHERE redact_msg_id IS NULL
              AND (itime < (now() - '${timeout}m'::interval))|);

  $dbh->do(qq|DELETE FROM async_events
              WHERE redact_msg_id IS NOT NULL
              AND (itime < (now() - '${timeout_redacted}m'::interval))|);

  1;
}

1;
