# @tag: convert_taxzone
# @description: Setzt Fremdschlüssel und andere constraints auf die Tabellen tax und taxkeys
# @depends: taxzone_charts
package SL::DBUpgrade2::convert_taxzone;

use strict;
use utf8;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

    # extract all buchungsgruppen data
    my $buchungsgruppen_query = <<SQL;
      SELECT * from buchungsgruppen;
SQL

    my $sth = $self->dbh->prepare($buchungsgruppen_query);
    $sth->execute || $::form->dberror($buchungsgruppen_query);

    $::form->{buchungsgruppen} = [];
    while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
      push @{ $::form->{buchungsgruppen} }, $ref;
    }
    $sth->finish;

    # extract all tax_zone data
    my $taxzone_query = <<SQL;
      SELECT * from tax_zones;
SQL

    $sth = $self->dbh->prepare($taxzone_query);
    $sth->execute || $::form->dberror($taxzone_query);

    $::form->{taxzones} = [];
    while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
      push @{ $::form->{taxzones} }, $ref;
    }
    $sth->finish;

    my $taxzone_charts_update_query = "INSERT INTO taxzone_charts (taxzone_id, buchungsgruppen_id, income_accno_id, expense_accno_id) VALUES (?, ?, ?, ?)";
    $sth = $self->dbh->prepare($taxzone_charts_update_query);

    # convert Buchungsgruppen to taxzone_charts if any exist
    # the default swiss COA doesn't have any, for example
    if ( scalar @{ $::form->{buchungsgruppen} } > 0 ) {
        foreach my $taxzone (  @{$::form->{taxzones}} ) {
            foreach my $buchungsgruppe (  @{$::form->{buchungsgruppen}} ) {
                my $id = $taxzone->{id};
                my $income_accno_id = $buchungsgruppe->{"income_accno_id_$id"};
                my $expense_accno_id = $buchungsgruppe->{"expense_accno_id_$id"};
                my @values           = ($taxzone->{id}, $buchungsgruppe->{id}, $income_accno_id, $expense_accno_id);
                $sth->execute(@values) && next;
                $taxzone_charts_update_query =~ s{\?}{shift(@values)}eg;
                $::form->dberror($taxzone_charts_update_query);
            };
        };
    };

    $sth->finish;

    my $clean_buchungsgruppen_query = <<SQL;
alter table buchungsgruppen drop column income_accno_id_0;
alter table buchungsgruppen drop column income_accno_id_1;
alter table buchungsgruppen drop column income_accno_id_2;
alter table buchungsgruppen drop column income_accno_id_3;
alter table buchungsgruppen drop column expense_accno_id_0;
alter table buchungsgruppen drop column expense_accno_id_1;
alter table buchungsgruppen drop column expense_accno_id_2;
alter table buchungsgruppen drop column expense_accno_id_3;
SQL
  $sth = $self->dbh->prepare($clean_buchungsgruppen_query);
  $sth->execute || $::form->dberror($clean_buchungsgruppen_query);
  return 1;
} # end run

1;
