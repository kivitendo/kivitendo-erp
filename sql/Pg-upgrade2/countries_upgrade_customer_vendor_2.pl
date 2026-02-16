# @tag: countries_upgrade_customer_vendor_2
# @description: Setzt Länder-Auswahlmenü als Pflichtfeld (not null) für Kunden und Lieferanten
# @depends: release_3_9_2 countries_upgrade_customer_vendor
package SL::DBUpgrade2::countries_upgrade_customer_vendor_2;

use strict;
use utf8;

use SL::DB::Country;
use SL::DB::Customer;
use SL::DB::Vendor;
use SL::Controller::Helper::ReportGenerator;
use SL::Presenter::Tag qw(input_tag html_tag select_tag submit_tag);

use parent qw(SL::DBUpgrade2::Base);

sub print_errors {
  my ($self, $missing) = @_;

  $::form->{title} = $::locale->text('Country Names');

  my @columns = qw(old_name country_id);
  my %column_defs = (
    old_name   => { text => $::locale->text('old') },
    country_id => { text => $::locale->text('new') },
  );
  map { $column_defs{$_}{visible} = 1 } @columns;

  my $report = SL::ReportGenerator->new(\%::myconfig, $::form);
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_options(
    title                => $::form->{title},
    allow_chart_export   => 0,
    allow_csv_export     => 0,
    allow_pdf_export     => 0,
    raw_top_info_text    =>
      '<div class="wrapper"><form name="Form" method="post" action="login.pl"><input type="hidden" name="action" value="login">' .
      html_tag('p', 'The following country names must be assigned to countries from the ISO 3166-1 alpha-2 code list, as automatic assignment failed for these.'),
    raw_bottom_info_text =>
      submit_tag('rerun_countries_upgrade_customer_vendor_2', $::locale->text('Rerun update')) .
      '</form></div>',
  );

  my $all_countries = SL::DB::Manager::Country->get_all(sort_by => 'description');

  foreach my $old_country (keys %$missing) {
    $report->add_data({
      old_name   => { data => $old_country },
      country_id => { raw_data => select_tag('missing.'.$old_country, $all_countries, value_key => 'id', title_key => 'description', default => $missing->{$old_country}, class => 'wi-wide') },
    });
  }

  print $report->generate_html_content();
}


sub run {
  my ($self) = @_;

  my @errors = ();
  my %missing = %{$::form->{missing} // {}};

  SL::DB->client->with_transaction(sub {
    my $customers = SL::DB::Manager::Customer->get_all(sort_by => 'customernumber');
    my $vendors   = SL::DB::Manager::Vendor  ->get_all(sort_by => 'vendornumber');
    my $countries = SL::DB::Manager::Country ->get_all(sort_by => 'id');
    my %country_id_by_iso2 = map { $_->iso2 => $_->id } @$countries;

    foreach my $cv (@$customers, @$vendors) {
      my $country_id = $cv->country ? $country_id_by_iso2{ SL::Helper::ISO3166::map_name_to_alpha_2_code($cv->country) } : undef;
      unless ($country_id) {
        if (defined $missing{$cv->country}) {
          $country_id = $missing{$cv->country};
        } else {
          $missing{$cv->country} = '';
        }
      }

      $cv->country_id($country_id);
      $cv->save;
    }

    if (scalar (grep { !$missing{$_} } keys %missing)) {
      $self->print_errors(\%missing);
      return 2;
    }
    return 0 if scalar @errors;

    my $query = qq|ALTER TABLE customer ALTER COLUMN country_id SET NOT NULL;
                   ALTER TABLE vendor   ALTER COLUMN country_id SET NOT NULL;|;

  #  $self->db_query($query);
  #my $sth = $self->dbh->prepare($query);
  #$sth->execute || $self->dberror($query);

    1;
  }) ;#or do { die SL::DB->client->error };
}

1;
