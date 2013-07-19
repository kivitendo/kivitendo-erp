# @tag: defaults_feature
# @description: Einstellen der Feature vom Config-File in die DB verlagern.
# @depends: release_3_0_0
package SL::DBUpgrade2::defaults_feature;

use utf8;

use parent qw(SL::DBUpgrade2::Base);
use strict;

sub run {
  my ($self) = @_;

  # this query will fail if column already exist (new database)
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN webdav              boolean DEFAULT false|);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN webdav_documents    boolean DEFAULT false|);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN vertreter           boolean DEFAULT false|);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN parts_show_image    boolean DEFAULT true|);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN parts_listing_image boolean DEFAULT true|);
  $self->db_query(qq|ALTER TABLE defaults ADD COLUMN parts_image_css     text    DEFAULT 'border:0;float:left;max-width:250px;margin-top:20px:margin-right:10px;margin-left:10px;'|);

  # check current configuration and set default variables accordingly, so that
  # kivitendo's behaviour isn't changed by this update
  my %old_defaults = ( parts_show_image => 1 );

  foreach my $check (qw(webdav vertreter parts_show_image parts_listing_image)) {
    my $check_set = exists $::lx_office_conf{features}->{$check} ? $::lx_office_conf{features}->{$check} : $old_defaults{$check};
    $self->db_query("UPDATE defaults SET $check = ?", bind => [ $check_set ? 1 : 0 ]);
  }

  if (exists $::lx_office_conf{features}->{parts_image_css}) {
    my $update_column = "UPDATE defaults SET parts_image_css = ?";
    $self->db_query($update_column, bind => [ $::lx_office_conf{features}->{parts_image_css} ]);
  }

  return 1;
}

1;
