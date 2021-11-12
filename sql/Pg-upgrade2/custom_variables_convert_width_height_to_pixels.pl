# @tag: custom_variables_convert_width_height_to_pixels
# @description: Benutzerdefinierte Variablen: Optionen »WIDTH« & »HEIGHT« nach Pixel konvertieren
# @depends: release_3_5_8
package SL::DBUpgrade2::custom_variables_convert_width_height_to_pixels;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub find_configs {
  my ($self) = @_;

  my $sql = <<SQL;
    SELECT id, options
    FROM custom_variable_configs
    WHERE (COALESCE(options, '') ~ 'WIDTH=|HEIGHT=')
      AND (type = 'textfield')
SQL

  return selectall_hashref_query($::form, $self->dbh, $sql);
}

sub fix_configs {
  my ($self, $configs) = @_;

  my $sql = <<SQL;
    UPDATE custom_variable_configs
    SET options = ?
    WHERE id = ?
SQL

  my $update_h = prepare_query($::form, $self->dbh, $sql);

  # Old defaults: 30 columns, 5 rows
  # New defaults: 225px width, 90px height

  foreach my $config (@{ $configs }) {
    $config->{options} =~ s{WIDTH=(\d+)}{  int($1 * (225 / 30.0)) }eg;
    $config->{options} =~ s{HEIGHT=(\d+)}{ int($1 * ( 90 /  5.0)) }eg;

    $update_h->execute(@{$config}{qw(options id)}) || $self->db_error($sql);
  }

  $update_h->finish;
}

sub run {
  my ($self) = @_;

  my $configs = $self->find_configs;
  $self->fix_configs($configs) if @{ $configs };

  return 1;
}

1;
