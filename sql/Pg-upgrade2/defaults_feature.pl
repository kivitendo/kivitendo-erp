# @tag: defaults_feature
# @description: Einstellen der Feature vom Config-File in die DB verlagern.
# @depends: release_3_0_0
# @ignore: 0
package SL::DBUpgrade2::defaults_feature;

use utf8;

use parent qw(SL::DBUpgrade2::Base);
use strict;

sub run {
  my ($self) = @_;

  # this query will fail if column already exist (new database)
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN webdav boolean DEFAULT false|, may_fail => 1);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN webdav_documents boolean   DEFAULT false|, may_fail => 1);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN vertreter boolean DEFAULT false|, may_fail => 1);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN parts_show_image boolean   DEFAULT true|, may_fail => 1);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN parts_listing_image boolean   DEFAULT true|, may_fail => 1);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN parts_image_css text   DEFAULT 'border:0;float:left;max-width:250px;margin-top:20px:margin-right:10px;margin-left:10px;' |, may_fail => 1);

  # check current configuration and set default variables accordingly, so that
  # kivitendo's behaviour isn't changed by this update
  # if checks are not set in config set it to true
  foreach my $check (qw(webdav vertreter parts_show_image parts_listing_image)) {
    my $check_set = 1;
    if (!$::lx_office_conf{features}->{$check}) {
      $check_set = 0;
    }

    my $update_column = "UPDATE defaults SET $check = '$check_set';";
    $self->db_query($update_column);
  }
  my $update_column = "UPDATE defaults SET parts_image_css = '$::lx_office_conf{features}->{parts_image_css};'";
  $self->db_query($update_column);


  return 1;
}

1;
