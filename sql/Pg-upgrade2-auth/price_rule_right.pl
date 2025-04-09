# @tag: price_rule_right
# @description: Neues Gruppenrecht für Preisregeln
# @depends: release_3_9_2 add_master_rights
# @locales: Price Rules
package SL::DBUpgrade2::Auth::price_rule_right;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  do_query($::form, $self->dbh, "INSERT INTO auth.master_rights (position, name, description) VALUES ((SELECT max(position)+1 FROM auth.master_rights), 'price_rules', 'Price Rules')");
  $::auth->{master_rights} = undef;

  my $groups = $::auth->read_groups;

  foreach my $group (values %{$groups}) {
    $group->{rights}->{price_rules} = $group->{rights}->{part_service_assembly_edit} ? 1 : 0;
    $::auth->save_group($group);
  }

  return 1;
}

1;
