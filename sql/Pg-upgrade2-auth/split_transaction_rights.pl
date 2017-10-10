# @tag: split_transaction_rights
# @description: Finanzbuchhaltungsrechte für Buchungen aufspalten
# @depends: release_3_4_0 master_rights_position_gaps
# @locales: General Ledger Transaction
# @locales: AR Transactions
# @locales: AP Transactions


package SL::DBUpgrade2::Auth::split_transaction_rights;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES (3130,'gl_transactions','General Ledger Transaction')");
  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES (3150,'ar_transactions','AR Transactions')");
  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES (3170,'ap_transactions','AP Transactions')");
  $self->db_query("UPDATE auth.master_rights SET description='General Ledger' WHERE name='general_ledger'");

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{gl_transactions} = $group->{rights}->{general_ledger};
    $group->{rights}->{ar_transactions} = $group->{rights}->{general_ledger};
    $group->{rights}->{ap_transactions} = $group->{rights}->{general_ledger};
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
