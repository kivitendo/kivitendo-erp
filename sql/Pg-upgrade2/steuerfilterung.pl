# @tag: steuerfilterung
# @description: Steuern in Dialogbuchungen filtern.
# @depends: release_3_0_0
package SL::DBUpgrade2::steuerfilterung;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  if ( $::form->{'continued'} ) {
    my $update_query = qq|ALTER TABLE tax ADD chart_categories TEXT|;
    $self->db_query($update_query);
    my $categories;
    my $tax_id;
    foreach my $i (1 .. $::form->{rowcount}) {
      $tax_id = $::form->{"tax_id_$i"};
      $categories = '';
      $categories .= 'A' if $::form->{"asset_$i"};
      $categories .= 'L' if $::form->{"liability_$i"};
      $categories .= 'Q' if $::form->{"equity_$i"};
      $categories .= 'C' if $::form->{"costs_$i"};
      $categories .= 'I' if $::form->{"revenue_$i"};
      $categories .= 'E' if $::form->{"expense_$i"};
      $update_query = qq|UPDATE tax SET chart_categories = '$categories' WHERE id=$tax_id|;
      $self->db_query($update_query);
    }
    $update_query = qq|ALTER TABLE tax ALTER COLUMN chart_categories SET NOT NULL|;
    $self->db_query($update_query);
    $self->dbh->commit();
    return 1;
  }

  my $query = qq|SELECT taxkey, taxdescription, rate, id AS tax_id FROM tax order by taxkey, rate|;

  my $sth = $self->dbh->prepare($query);
  $sth->execute || $::form->dberror($query);

  $::form->{PARTS} = [];
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    $ref->{rate} = $::form->format_amount(\%::myconfig, $::form->round_amount($ref->{rate} * 100));
    push @{ $::form->{PARTS} }, $ref;
  }

  &print_message;
  return 2;
} # end run

sub print_message {
  print $::form->parse_html_template("dbupgrade/steuerfilterung");
}

1;
