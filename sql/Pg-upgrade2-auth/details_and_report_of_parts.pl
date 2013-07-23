# @tag: details_and_report_of_parts
# @description: Setzt das Recht zur Anzeige von Details und Berichten von Waren, Dienstleistungen und Erzeugnissen
# @depends: release_3_0_0
package SL::DBUpgrade2::details_and_report_of_parts;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{part_service_assembly_details} = $group->{rights}->{part_service_assembly_edit};
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
