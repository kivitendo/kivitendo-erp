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

  if ( $::form->{'continued'} ) {
    my $update_query;
    foreach my $i (1 .. $::form->{rowcount}) {
      $update_query = qq|UPDATE parts SET partnumber = '| . $::form->{"partnumber_$i"} . qq|' WHERE id = | . $::form->{"partid_$i"};
      $self->db_query($update_query);
      print FH $i;
    }
    $self->dbh->commit();
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

1;
