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
use SL::Locale::String qw(t8);
use SL::Presenter::Tag qw(input_tag html_tag select_tag submit_tag);
use SL::DBUtils;

use parent qw(SL::DBUpgrade2::Base);

sub print_errors {
  my ($self, $missing) = @_;

  $::form->{title} = t8('Country Names');

  my @columns = qw(old_name country_id);
  my %column_defs = (
    old_name   => { text => t8('old') },
    country_id => { text => t8('new') },
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
      submit_tag('rerun_countries_upgrade_customer_vendor_2', t8('Rerun update')) .
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
    my ($query, $sth);

    $query = 'SELECT id, iso2 FROM countries;';
    $sth = $self->dbh->prepare($query);
    $sth->execute || $self->dberror($query);
    my $countries = $sth->fetchall_arrayref();
    my %country_id_by_iso2 = map { $_->[1] => $_->[0] } @$countries;

    $query = 'SELECT distinct(country) FROM customer
              UNION ALL
              SELECT distinct(country) FROM vendor;';
    $sth = $self->dbh->prepare($query);
    $sth->execute || $self->dberror($query);
    my %country_id_by_country_name = ();
    while (my $cv = $sth->fetchrow_hashref()) {
      my $country_id = $cv->{country} ? $country_id_by_iso2{ SL::Helper::ISO3166::map_name_to_alpha_2_code($cv->{country}) } : undef;
      unless ($country_id) {
        if (defined $missing{$cv->{country}}) {
          $country_id = $missing{$cv->{country}};
        } else {
          $missing{$cv->{country}} = '';
          next;
        }
      }

      $country_id_by_country_name{$cv->{country}} = $country_id;
    }

    if (scalar (grep { !$missing{$_} } keys %missing)) {
      $self->print_errors(\%missing);
      return 2;
    }
    return 0 if scalar @errors;

    $query = 'UPDATE customer SET country_id = ? WHERE country = ?;';
    $sth = $self->dbh->prepare($query);
    foreach my $name (keys %country_id_by_country_name) {
      do_statement($::form, $sth, $query, $country_id_by_country_name{$name}, $name);
    }

    $query = 'UPDATE vendor SET country_id = ? WHERE country = ?;';
    $sth = $self->dbh->prepare($query);
    foreach my $name (keys %country_id_by_country_name) {
      do_statement($::form, $sth, $query, $country_id_by_country_name{$name}, $name);
    }


    $query = 'ALTER TABLE customer ALTER COLUMN country_id SET NOT NULL;
              ALTER TABLE vendor   ALTER COLUMN country_id SET NOT NULL;';
    $sth = $self->dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    $query = 'ALTER TABLE customer DROP COLUMN country;
              ALTER TABLE vendor   DROP COLUMN country;';
    $sth = $self->dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    1;
  }) ;#or do { die SL::DB->client->error };
}

1;
