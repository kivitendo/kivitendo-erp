# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::TaxzoneChart;

use strict;

use SL::DB::MetaSetup::TaxzoneChart;
use SL::DB::Manager::TaxzoneChart;
use SL::DB::MetaSetup::Buchungsgruppe;

__PACKAGE__->meta->initialize;

# Creates get_all, get_all_count, get_all_iterator, delete_all and update_all.
#__PACKAGE__->meta->make_manager_class;

sub get_all_accounts_by_buchungsgruppen_id {
  my ($self, $buchungsgruppen_id) = @_;

  my $all_taxzonecharts = SL::DB::Manager::TaxzoneChart->get_all(where   => [ buchungsgruppen_id => $buchungsgruppen_id ],
                                                                 sort_by => 'taxzone_id');

  my %list = ();

  # inventory_accno and description of the Buchungsgruppe:
  $list{inventory_accno}             = SL::DB::Manager::Buchungsgruppe->find_by(id => $buchungsgruppen_id)->inventory_account->accno;
  $list{inventory_accno_description} = SL::DB::Manager::Buchungsgruppe->find_by(id => $buchungsgruppen_id)->inventory_account->displayable_name;

  foreach my $taxzonechart (@{ $all_taxzonecharts }) {
    $list{ $taxzonechart->taxzone_id }{taxzone_chart_id}          = $taxzonechart->id;
    $list{ $taxzonechart->taxzone_id }{income_accno}              = $taxzonechart->income_accno->accno;
    $list{ $taxzonechart->taxzone_id }{expense_accno}             = $taxzonechart->expense_accno->accno;
    $list{ $taxzonechart->taxzone_id }{income_accno_id}           = $taxzonechart->income_accno->id;
    $list{ $taxzonechart->taxzone_id }{expense_accno_id}          = $taxzonechart->expense_accno->id;
    $list{ $taxzonechart->taxzone_id }{income_accno_description}  = $taxzonechart->income_accno->displayable_name;
    $list{ $taxzonechart->taxzone_id }{expense_accno_description} = $taxzonechart->expense_accno->displayable_name;
  }
  return \%list;
}

sub get_all_accounts_by_taxzone_id {
  my ($self, $taxzone_id) = @_;

  my $all_taxzonecharts = SL::DB::Manager::TaxzoneChart->get_all(where => [ taxzone_id => $taxzone_id ]);

  my %list = ();

  foreach my $tzchart (@{ $all_taxzonecharts }) {
    $list{ $tzchart->buchungsgruppen_id }{taxzone_chart_id}          = $tzchart->id;
    $list{ $tzchart->buchungsgruppen_id }{income_accno}              = $tzchart->income_accno->accno;
    $list{ $tzchart->buchungsgruppen_id }{expense_accno}             = $tzchart->expense_accno->accno;
    $list{ $tzchart->buchungsgruppen_id }{income_accno_id}           = $tzchart->income_accno->id;
    $list{ $tzchart->buchungsgruppen_id }{expense_accno_id}          = $tzchart->expense_accno->id;
    $list{ $tzchart->buchungsgruppen_id }{income_accno_description}  = $tzchart->income_accno->displayable_name;
    $list{ $tzchart->buchungsgruppen_id }{expense_accno_description} = $tzchart->expense_accno->displayable_name;
  }

  return \%list;
}

1;
