# @tag: umstellung_eur
# @description: Variable eur umstellen: bitte in doc/dokumentation.pdf das entsprechende Kapitel zur Konfiguration von EUR lesen
# @depends: release_2_6_3
package SL::DBUpgrade2::umstellung_eur;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

# this script relies on $eur still being set in kivitendo.conf, and the
# variable available in $::lx_office_conf{system}->{eur}

sub run {
  my ($self) = @_;

  # check if accounting_method has already been set (new database), if so return
  # only set variables according to eur for update of existing database


  foreach my $column (qw(accounting_method inventory_system profit_determination)) {
    # this query will fail if columns already exist (new database)
    $self->db_query(qq|ALTER TABLE defaults ADD COLUMN ${column} TEXT|, may_fail => 1);
  }

  my $accounting_method;
  my $inventory_system;
  my $profit_determination;

  # check current configuration and set default variables accordingly, so that
  # kivitendo behaviour isn't changed by this update

  if (!defined $::lx_office_conf{system}->{eur} || $::lx_office_conf{system}->{eur} == 0 ) {
    $accounting_method = 'accrual';
    $inventory_system = 'perpetual';
    $profit_determination = 'balance';
  } elsif ( $::lx_office_conf{system}->{eur} == 1 ) {
    $accounting_method = 'cash';
    $inventory_system = 'periodic';
    $profit_determination = 'income';
  } else {
    die "illegal configuration of eur, must be 0 or 1, not " . $::lx_office_conf{system}->{eur} . "\n";
    # or maybe just return 1, dont do anything, because we assume everything is
    # already set, or has maybe already been deleted
  };

  # only set parameters if they haven't already been set (this in only the case
  # when upgrading)

  my $update_eur = "UPDATE defaults set accounting_method = '$accounting_method' where accounting_method is null;" .
                   "UPDATE defaults set inventory_system = '$inventory_system' where inventory_system is null; " .
                   "UPDATE defaults set profit_determination = '$profit_determination' where profit_determination is null;";
  $self->db_query($update_eur);

  return 1;
}

1;
