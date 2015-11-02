# @tag: defaults_datev_check
# @description: Einstellung für DATEV-Überprüfungen (datev_check) vom Config-File in die DB verlagern.
# @depends: release_2_7_0
package SL::DBUpgrade2::defaults_datev_check;

use utf8;

use parent qw(SL::DBUpgrade2::Base);
use strict;

sub run {
  my ($self) = @_;

  # this query will fail if column already exist (new database)
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN datev_check_on_sales_invoice boolean    DEFAULT true|, may_fail => 1);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN datev_check_on_purchase_invoice boolean DEFAULT true|, may_fail => 1);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN datev_check_on_ar_transaction boolean   DEFAULT true|, may_fail => 1);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN datev_check_on_ap_transaction boolean   DEFAULT true|, may_fail => 1);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN datev_check_on_gl_transaction boolean   DEFAULT true|, may_fail => 1);

  # check current configuration and set default variables accordingly, so that
  # kivitendo's behaviour isn't changed by this update
  # if checks are not set in config set it to true
  foreach my $check (qw(check_on_sales_invoice check_on_purchase_invoice check_on_ar_transaction check_on_ap_transaction check_on_gl_transaction)) {
    my $check_set     = defined($::lx_office_conf{datev_check}->{$check}) && ($::lx_office_conf{datev_check}->{$check} == 0) ? 0 : 1;
    my $update_column = "UPDATE defaults SET datev_$check = '$check_set';";
    $self->db_query($update_column);
  }

  return 1;
}

1;
