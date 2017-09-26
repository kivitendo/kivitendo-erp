# @tag: webshop_api_rights
# @description: Setzt die Rechte Shopconfig, Shopbestellungen, Shopartikel, per Default erlaubt
# @depends: release_3_5_0
# @locales: create and edit shopparts
# @locales: get shoporders
# @locales: create and edit webshops

package sl::dbupgrade2::auth::webshop_api_rights;

use strict;
use utf8;

use parent qw(sl::dbupgrade2::base);

use sl::dbutils;

sub run {
  my ($self) = @_;

  $self->db_query("insert into auth.master_rights (position, name, description) values ( 550,  'shop_part_edit',   'create and edit shopparts')");
  $self->db_query("insert into auth.master_rights (position, name, description) values ( 950,  'shop_order',       'get shoporders')");
  $self->db_query("insert into auth.master_rights (position, name, description) values ( 4300, 'edit_shop_config', 'create and edit webshops')");

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
