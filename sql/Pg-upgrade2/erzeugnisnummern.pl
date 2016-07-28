# @tag: erzeugnisnummern
# @description: Erzeugnisnummern und Artikelnummern sollen eindeutig sein.
# @depends: release_3_0_0
package SL::DBUpgrade2::erzeugnisnummern;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

use SL::DBUtils;

sub run {
  my ($self) = @_;

  if (defined $::form->{upgrade_action} && $::form->{upgrade_action} eq 'filter_parts') {
    return $self->filter_parts($self);
  }

  if ( $::form->{'continued'} ) {
    my $update_query;
    foreach my $i (1 .. $::form->{rowcount}) {
      $update_query = qq|UPDATE parts SET partnumber = '| . $::form->{"partnumber_$i"} . qq|' WHERE id = | . $::form->{"partid_$i"};
      $self->db_query($update_query);
    }
  }

  my $query = qq|SELECT id, partnumber, description, unit, notes, assembly, ean, inventory_accno_id, obsolete
                   FROM parts pa
                   WHERE (SELECT COUNT(*)
                          FROM parts p
                          WHERE p.partnumber=pa.partnumber)
                          > 1
                   ORDER BY partnumber;|;

  $::form->{PARTS} = [ selectall_hashref_query($::form, $self->dbh, $query) ];

  if ( scalar @{ $::form->{PARTS} } > 0 ) {
    &print_error_message;
    return 2;
  }

  $query = qq|ALTER TABLE parts ADD UNIQUE (partnumber)|;
  $self->db_query($query);

  $query = qq|ALTER TABLE defaults ADD assemblynumber TEXT|;
  $self->db_query($query);
  return 1;
} # end run

sub print_error_message {
  print $::form->parse_html_template("dbupgrade/erzeugnisnummern");
}

sub filter_parts {
  my $self = shift;

  my $where = 'TRUE';
  my @values;

  if ( $::form->{filter_partnumber} ) {
    $where .= ' AND partnumber ILIKE ?';
    push(@values, like( $::form->{filter_partnumber} ));
  }

  if ($::form->{filter_description}) {
    $where .= ' AND description ILIKE ?';
    push(@values, like($::form->{filter_description}));
  }

  if ($::form->{filter_notes}) {
    $where .= ' AND notes ILIKE ?';
    push(@values, like($::form->{filter_notes}));
  }

  if ($::form->{filter_ean}) {
    $where .= ' AND ean ILIKE ?';
    push(@values, like($::form->{filter_ean}));
  }

  if ($::form->{filter_type} eq 'assembly') {
    $where .= " AND part_type = 'assembly'";
  }

  if ($::form->{filter_type} eq 'service') {
    $where .= " AND part_type = 'service'";
  }

  if ($::form->{filter_type} eq 'part') {
    $where .= " AND part_type = 'part'";
  }

  if ($::form->{filter_obsolete} eq 'obsolete') {
    $where .= ' AND obsolete';
  }

  if ($::form->{filter_obsolete} eq 'valid') {
    $where .= ' AND NOT obsolete';
  }

  my $query = qq|SELECT id, partnumber, description, unit, notes, assembly, ean, inventory_accno_id, obsolete
                 FROM parts
                 WHERE $where
                 ORDER BY partnumber|;

  $::form->{ALL_PARTS} = [ selectall_hashref_query($::form, $self->dbh, $query, @values) ];

  print $::form->parse_html_template("dbupgrade/show_partlist");
  return 2;
}

1;
