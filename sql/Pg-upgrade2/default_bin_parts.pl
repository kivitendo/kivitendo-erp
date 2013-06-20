# @tag: default_bin_parts
# @description: Freitext Feld Lagerplatz nach Lager und Lagerplatz migrieren
# @depends: release_3_0_0 add_warehouse_defaults

package SL::DBUpgrade2::default_bin_parts;

use strict;
use utf8;
use Data::Dumper;
use SL::DBUtils;
use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;
  $::form->get_lists('warehouses' => { 'key'    => 'WAREHOUSES',
                                     'bins'   => 'BINS', });
  if (scalar @{ $::form->{WAREHOUSES} }) {
    $::form->{warehouse_id} ||= $::form->{WAREHOUSES}->[0]->{id};
    $::form->{bin_id}       ||= $::form->{WAREHOUSES}->[0]->{BINS}->[0]->{id};
  } else {
    $::form->{NO_WAREHOUSE} = 1;
  }
    $::form->{warehouse_id} = 0;    # 0 ist die ID für leere Option

  if ( $::form->{'continued'} ) {
    my $CREATE_BINS      = 0;
    my $CREATE_WAREHOUSE = 0;
    if (!defined($::form->{NO_WAREHOUSE}) && defined($::form->{create_new_bins}) && $::form->{warehouse_id_default}) {
      $CREATE_BINS = 1;
    }
    if (defined($::form->{NO_WAREHOUSE}) && defined($::form->{create_new_bins}) && $::form->{new_warehouse}) {
      $CREATE_WAREHOUSE = 1;
      $CREATE_BINS      = 1;
    }

    # Lager anlegen
    my $insert_warehouse_query = qq|INSERT into warehouse (description, invalid, sortkey) VALUES (?, 'false', 1) |;
    my $prepared_insert_warehouse_query   = $self->dbh->prepare($insert_warehouse_query)   || $self->db_error($insert_warehouse_query);

    # Lagerplatz anlegen
    my $insert_bin_query = qq|INSERT into bin (description, warehouse_id) VALUES (?, ?) |;
    my $prepared_insert_bin_query   = $self->dbh->prepare($insert_bin_query)   || $self->db_error($insert_bin_query);

    # Lagerplatz aus Liste zuweisen
    my $update_query = qq|UPDATE parts SET warehouse_id = ?, bin_id = ? WHERE id = ?|;
    my $prepared_update_query   = $self->dbh->prepare($update_query)   || $self->db_error($update_query);


    # gerade angelegten Lagerplatz zuweisen
    my $update_new_bin_query = qq|UPDATE parts SET warehouse_id = (SELECT warehouse_id from bin where description = ?),
                                           bin_id       = (SELECT id from bin where description       = ?)
                                           WHERE id = ?|;
    my $prepared_update_new_bin_query   = $self->dbh->prepare($update_new_bin_query)   || $self->db_error($update_new_bin_query);


    # kein lager vorhanden, aber wir legen ein neues an.
    if ($CREATE_WAREHOUSE && $CREATE_BINS) {
      $prepared_insert_warehouse_query->execute($::form->{new_warehouse}) || $self->db_error($insert_warehouse_query);
      $prepared_insert_warehouse_query->finish();
      my $query = qq|SELECT id FROM warehouse LIMIT 1;|;
      my $sth = $self->dbh->prepare($query);
      $sth->execute || $::form->dberror($query);
      $::form->{warehouse_id_default} = $sth->fetchrow_array();
    }

    foreach my $i (1 .. $::form->{rowcount}) {

      # Best Case: Lagerplatz aus Liste gewählt
      # bei zurückspringen auf leeres lager, wird der lagerplatz nicht zurückgesetzt
      # erstmal an dieser stelle abfangen, damit nichts angelegt wird
      if ($::form->{"bin_id_$i"} && $::form->{"warehouse_id_$i"}) {
        $prepared_update_query->execute($::form->{"warehouse_id_$i"}, $::form->{"bin_id_$i"}, $::form->{"partid_$i"}) || $self->db_error($update_query);
      } elsif ($CREATE_BINS) {
        # Lager vorhanden, bzw. vorher erstellt.  alte bins automatisch hinzufügen und zum Standardlagerplatz verdrahten
        $prepared_insert_bin_query->execute($::form->{"bin_$i"}, $::form->{warehouse_id_default}) || $self->db_error($insert_bin_query);
        $prepared_update_new_bin_query->execute($::form->{"bin_$i"}, $::form->{"bin_$i"}, $::form->{"partid_$i"}) || $self->db_error($update_new_bin_query);
      }
    }
    $prepared_insert_bin_query->finish();
    $prepared_update_new_bin_query->finish();
    $prepared_update_query->finish();
    $::form->{FINISH} = 1;
    # das alte textfeld entfernen
    #my $query = qq|ALTER TABLE parts drop COLUMN bin|;
    #$self->db_query($query);
    #return 1;
  }

  my $query = qq|SELECT id, partnumber, description, bin
                   FROM parts pa
                   WHERE '' <> NULLIF ( bin, '')
                   ORDER BY partnumber;|;

  my $sth = $self->dbh->prepare($query);
  $sth->execute || $::form->dberror($query);

  $::form->{PARTS} = [ selectall_hashref_query($::form, $self->dbh, $query) ];

  if ( (scalar @{ $::form->{PARTS} } > 0 ) && !$::form->{NO_WAREHOUSE} && !$::form->{FINISH} )  {
    &print_error_message;
    return 2;
  } elsif ( (scalar @{ $::form->{PARTS} } > 0 ) && $::form->{NO_WAREHOUSE} && !$::form->{FINISH} ) {
    &print_error_message_no_warehouse;
    return 2;
  }
  # das alte textfeld entfernen
  # hier nochmal, da oben schon ein return 1 gesetzt ist
  $query = qq|ALTER TABLE parts drop COLUMN bin|;
  $self->db_query($query);
  return 1;
}

sub print_error_message {
  print $::form->parse_html_template("dbupgrade/default_bin_parts");
}

sub print_error_message_no_warehouse {
  print $::form->parse_html_template("dbupgrade/default_bin_parts_no_warehouse");
}


1;
