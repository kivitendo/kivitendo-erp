# @tag: customer_vendor_record_extra_tab_rights
# @description: Setzt Rechte um bei Kunden/Lieferanten einen Extratab anzeigen zu lassen, der Belege anzeigt per Default erlaubt
# @depends: release_3_5_2
# @locales: Show record tab in customer
# @locales: Show record tab in vendor
package SL::DBUpgrade2::Auth::customer_vendor_record_extra_tab_rights;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES ( 610,  'show_extra_record_tab_customer',   'Show record tab in customer')");
  $self->db_query("INSERT INTO auth.master_rights (position, name, description) VALUES ( 611,  'show_extra_record_tab_vendor',   'Show record tab in vendor')");

  my $groups = $main::auth->read_groups();

  foreach my $group (values %{$groups}) {
    $group->{rights}->{show_extra_record_tab_customer}   = 1;
    $group->{rights}->{show_extra_record_tab_vendor}     = 1;
    $main::auth->save_group($group);
  }

  return 1;
} # end run

1;
