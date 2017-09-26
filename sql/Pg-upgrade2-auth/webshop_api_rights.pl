# @tag: webshop_api_rights
# @description: Setzt die Rechte Shopconfig, Shopbestellungen, Shopartikel, per Default erlaubt
# @depends: release_3_5_0
# @locales: Create and edit shopparts
# @locales: Get shoporders
# @locales: Create and edit webshops
package SL::DBUpgrade2::Auth::webshop_api_rights;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES ( 550,  'shop_part_edit',   'Create and edit shopparts')");
  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES ( 950,  'shop_order',       'Get shoporders')");
  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES ( 4300, 'edit_shop_config', 'Create and edit webshops')");

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{shop_part_edit}   = 1;
    $group->{rights}->{shop_order}       = 1;
    $group->{rights}->{edit_shop_config} = 1;
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
