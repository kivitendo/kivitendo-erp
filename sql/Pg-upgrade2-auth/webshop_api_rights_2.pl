# @tag: webshop_api_rights_2
# @description: Setzt die Rechte Shopconfig, Shopbestellungen, Shopartikel, per Default nicht erlaubt
# @depends: webshop_api_rights
package SL::DBUpgrade2::Auth::webshop_api_rights_2;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  $self->db_query("UPDATE auth.master_rights SET position = 4250 WHERE name = 'edit_shop_config'");

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{shop_part_edit}   = 0;
    $group->{rights}->{shop_order}       = 0;
    $group->{rights}->{edit_shop_config} = 0;
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
