# @tag: steuerfilterung
# @description: Steuern in Dialogbuchungen filtern.
# @depends: release_3_0_0 tax_constraints
package SL::DBUpgrade2::steuerfilterung;

use strict;
use utf8;
use List::Util qw(first);

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my $categories;
  my $tax_id;

  my $query = qq|ALTER TABLE tax ADD chart_categories TEXT|;
  $self->db_query($query);

  if ( $::form->{continued_tax} ) {
    foreach my $i (1 .. $::form->{rowcount}) {
      $tax_id = $::form->{"tax_id_$i"};
      $categories = '';
      $categories .= 'A' if $::form->{"asset_$i"};
      $categories .= 'L' if $::form->{"liability_$i"};
      $categories .= 'Q' if $::form->{"equity_$i"};
      $categories .= 'C' if $::form->{"costs_$i"};
      $categories .= 'I' if $::form->{"revenue_$i"};
      $categories .= 'E' if $::form->{"expense_$i"};
      $self->db_query(qq|UPDATE tax SET chart_categories = ? WHERE id = ?|, bind => [ $categories, $tax_id ]);
    }
    $self->db_query(qq|UPDATE tax SET chart_categories = 'ALQCIE' WHERE chart_categories IS NULL|);
    $self->db_query(qq|ALTER TABLE tax ALTER COLUMN chart_categories SET NOT NULL|);
    return 1;
  }

  my @well_known_taxes = (
      # German SKR03
      { taxkey => 0,  rate => 0,    taxdescription => qr{keine.*steuer}i,                       categories => 'ALQCIE' },
      { taxkey => 1,  rate => 0,    taxdescription => qr{frei}i,                                categories => 'ALQCIE' },
      { taxkey => 2,  rate => 0.07, taxdescription => qr{umsatzsteuer}i,                        categories => 'I' },
      { taxkey => 3,  rate => 0.16, taxdescription => qr{umsatzsteuer}i,                        categories => 'I' },
      { taxkey => 3,  rate => 0.19, taxdescription => qr{umsatzsteuer}i,                        categories => 'I' },
      { taxkey => 5,  rate => 0.16, taxdescription => qr{umsatzsteuer}i,                        categories => 'I' },
      { taxkey => 7,  rate => 0.16, taxdescription => qr{vorsteuer}i,                           categories => 'E' },
      { taxkey => 8,  rate => 0.07, taxdescription => qr{vorsteuer}i,                           categories => 'E' },
      { taxkey => 9,  rate => 0.16, taxdescription => qr{vorsteuer}i,                           categories => 'E' },
      { taxkey => 9,  rate => 0.19, taxdescription => qr{vorsteuer}i,                           categories => 'E' },
      { taxkey => 10, rate => 0,    taxdescription => qr{andere.*steuerpflichtige.*lieferung}i, categories => 'I' },
      { taxkey => 11, rate => 0,    taxdescription => qr{frei.*innergem.*mit}i,                 categories => 'I' },
      { taxkey => 12, rate => 0.07, taxdescription => qr{steuerpflichtig.*lieferung.*erm}i,     categories => 'I' },
      { taxkey => 13, rate => 0.16, taxdescription => qr{steuerpflichtig.*lieferung.*voll}i,    categories => 'I' },
      { taxkey => 13, rate => 0.19, taxdescription => qr{steuerpflichtig.*lieferung.*voll}i,    categories => 'I' },
      { taxkey => 15, rate => 0.16, taxdescription => qr{steuerpflicht.*eg.*lieferung}i,        categories => 'I' },
      { taxkey => 17, rate => 0.16, taxdescription => qr{steuerpflicht.*eg.*erwerb}i,           categories => 'E' },
      { taxkey => 18, rate => 0.07, taxdescription => qr{innergem.*erwerb.*erm}i,               categories => 'E' },
      { taxkey => 19, rate => 0.16, taxdescription => qr{innergem.*erwerb.*voll}i,              categories => 'E' },
      { taxkey => 19, rate => 0.19, taxdescription => qr{innergem.*erwerb.*voll}i,              categories => 'E' },

      # Swiss
      { taxkey => 2,  rate => 0.08,  taxdescription => qr{mwst}i,                                categories => 'I' },
      { taxkey => 2,  rate => 0.081, taxdescription => qr{mwst}i,                                categories => 'I' },
      { taxkey => 3,  rate => 0.025, taxdescription => qr{mwst}i,                                categories => 'I' },
      { taxkey => 3,  rate => 0.026, taxdescription => qr{mwst}i,                                categories => 'I' },
      { taxkey => 4,  rate => 0.08,  taxdescription => qr{mwst}i,                                categories => 'E' },
      { taxkey => 4,  rate => 0.081, taxdescription => qr{mwst}i,                                categories => 'E' },
      { taxkey => 5,  rate => 0.025, taxdescription => qr{mwst}i,                                categories => 'E' },
      { taxkey => 5,  rate => 0.026, taxdescription => qr{mwst}i,                                categories => 'E' },
      { taxkey => 6,  rate => 0.08,  taxdescription => qr{mwst}i,                                categories => 'E' },
      { taxkey => 6,  rate => 0.081, taxdescription => qr{mwst}i,                                categories => 'E' },
      { taxkey => 7,  rate => 0.025, taxdescription => qr{mwst}i,                                categories => 'E' },
      { taxkey => 7,  rate => 0.026, taxdescription => qr{mwst}i,                                categories => 'E' },
  );

  $query = qq|SELECT taxkey, taxdescription, rate, id AS tax_id FROM tax order by taxkey, rate;|;

  my $sth = $self->dbh->prepare($query);
  $sth->execute || $::form->dberror($query);

  my $well_known_tax;

  $::form->{PARTS} = [];
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    $well_known_tax = first {
      ($ref->{taxkey} == $_->{taxkey})
      && ($ref->{rate} == $_->{rate})
      && ($ref->{taxdescription} =~ $_->{taxdescription})
    } @well_known_taxes;
    if ($well_known_tax) {
      $self->db_query(qq|UPDATE tax SET chart_categories = ? WHERE id = ?|, bind => [ $well_known_tax->{categories}, $ref->{tax_id} ]);
    } else {
      $ref->{rate} = $::form->format_amount(\%::myconfig, $ref->{rate} * 100);
      push @{ $::form->{PARTS} }, $ref;
    }
  }

  if (scalar @{ $::form->{PARTS} } > 0){
    &print_message;
    return 2;
  } else {
    $query = qq|ALTER TABLE tax ALTER COLUMN chart_categories SET NOT NULL|;
    $self->db_query($query);
    return 1;
  }
} # end run

sub print_message {
  print $::form->parse_html_template("dbupgrade/steuerfilterung");
}

1;
