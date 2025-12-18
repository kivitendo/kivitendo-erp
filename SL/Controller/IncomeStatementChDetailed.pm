package SL::Controller::IncomeStatementChDetailed;

use strict;
use parent qw(SL::Controller::IncomeStatementChBase);

use POSIX qw(strftime);

use SL::DBUtils;
use SL::DB::IncomeStatementChDetailedGroups;
use SL::DB::IncomeStatementChDetailedCategories;

use SL::Locale::String; # for t8()
use SL::Presenter::DatePeriodAdder qw(get_date_periods);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(show_accounts include_zero_amounts) ],
);

__PACKAGE__->run_before(sub { $::auth->assert('report'); });

# actions

sub action_report_settings {
  my ($self) = @_;

  $self->actionname('IncomeStatementChDetailed/list');
  $self->setup_report_settings_action_bar;

  $self->render(
    'income_statement_ch_detailed/report_settings',
    title => t8('Detailed Swiss Income Statement'
  ));
}

sub action_list {
  my ($self) = @_;

  $self->title(t8('Detailed Swiss Income Statement'));

  ### get and validate form parameters

  # get date periods
  $self->date_periods(get_date_periods($::form, 'dateperiod'));
  $self->validate_date_periods;

  $self->show_accounts($::form->{show_accounts} ? 1 : 0);
  $self->include_zero_amounts($::form->{include_zero_amounts} ? 1 : 0);

  $self->department_id($::form->{department_id} || undef);

  ### prepare report
  $self->controller_class('IncomeStatementChDetailed');
  $self->attachment_basename_prefix(t8('income_statement_ch_detailed'));
  $self->additional_hidden_variables(qw(show_accounts include_zero_amounts));
  $self->prepare_report;

  ### get report data and generate report
  my $report_data = $self->get_report_data;
  $self->report->add_data($report_data);

  $self->report->generate_with_headers;
}

# report data calculation

sub get_report_data {
  my ($self) = @_;

  ### this is the main function doing the calculations for the report
  # and preparing the rows for display
  #
  # NOTE: the structure of the Erfolgsrechnung (income statement) is defined
  # via the database tables ch_erfolgsrechnung_groups and ch_erfolgsrechnung_categories

  # groups are used for sub-total calculations, e.g.:
  #   Betrieblicher Ertrag aus Lieferungen und Leistungen
  #   Bruttoergebnis nach Material- und Warenaufwand
  #   Bruttoergebnis nach Personalaufwand
  #   etc.
  my $er_groups = SL::DB::Manager::IncomeStatementChDetailedGroups->get_all();

  # categories are used for sub-total calculations within a group, e.g.:
  #   30-38 	Nettoerlöse aus Lieferungen und Leistungen
  #   39 	    Bestandesänderungen an unfertigen und fertigen Erzeugnissen sowie an nicht fakturierten Dienstleistungen
  #   4       Material- und Warenaufwand
  #   etc.
  my $er_categories = SL::DB::Manager::IncomeStatementChDetailedCategories->get_all(with_objects => [ 'group' ],);

  # row_set accumulates the rows of the report
  my @row_set;
  # totals accumulates the overall totals for all groups
  my @totals = map { 0.0 } @{ $self->date_periods };

  for my $group (@{$er_groups}) {

    # get categories associated with the group
    my @categories = grep { $_->group->id == $group->id } @{$er_categories};

    for my $category (@categories) {

      # account_rows accumulates the rows for individual accounts within the category
      my @account_rows;
      # category_totals accumulates the totals for the category
      my @category_totals = map { 0.0 } @{ $self->date_periods };

      # get all accounts associated with the category
      my $accounts = SL::DB::Manager::Chart->get_all_sorted(where => [ pos_er_detailed => $category->id ]);

      for my $account (@{$accounts}) {

        my @account_totals = $self->get_account_totals($account);

        # accumulate totals
        for my $i (map { $_->{index} } @{ $self->date_periods }) {
          $category_totals[$i] += $account_totals[$i];
          $totals[$i]          += $account_totals[$i];
        }

        ### prepare individual accounts display
        # only show accounts with non zero amounts, unless include_zero_amounts is set
        if ($self->show_accounts && ($self->has_nonzero_amount(@account_totals) || $self->include_zero_amounts)) {
          my %data;
          $self->insert_description_columns(\%data, $account->accno, $account->description);
          $self->insert_date_period_columns_data(\%data, \@account_totals, 'numeric');
          push @account_rows, \%data;
        }
      }

      ### category subtotal display
      my $class = $self->show_accounts ? 'listsubtotal' : '';
      my %data;
      $self->insert_description_columns(\%data, $category->account_range, $category->description, $class);
      $self->insert_date_period_columns_data(\%data, \@category_totals, "$class numeric");
      push @row_set, \%data;

      ### display individual accounts if set
      if ($self->show_accounts) {
        @row_set = (@row_set, @account_rows);
      }
    }

    ### group total display
    # TODO: if last element use class listtotal (this is not critical, it looks fine already)
    my $class = $self->show_accounts ? 'listtotal' : 'listsubtotal';
    my %data;
    $self->insert_description_columns(\%data, "", $group->description, $class);
    $self->insert_date_period_columns_data(\%data, \@totals, "$class numeric");
    push @row_set, \%data;
  }
  return \@row_set;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::IncomeStatementChDetailed - Controller for the Detailed Swiss Income Statement (Erfolgsrechnung) report

=head1 SYNOPSIS

Controller for Reports -> Detailed Swiss Income Statement. Provides report generation and export (HTML/CSV, PDF via printing).

=head1 DESCRIPTION

The existing Swiss Income Statement (Erfolgsrechnung), implemented in rp.pl, is very basic and not sufficient
for most businesses. Therefore we implement a detailed version here, which conforms to swiss business practices.
Specifically this conforms to the "Mindestgliederung für den Schweizer Kontenrahmen für KMU, Produktionserfolgsrechnung
(Gesamtkostenverfahren)".

The earnings and expenses are grouped into categories and groups, with subtotals for each
category and group. The categories and groups are defined by database views generated by
../../sql/Pg-upgrade2/income_statement_ch_detailed_views.sql. This is done analogous/similar to the german reports of BWA
(Betriebswirtschaftliche Auswertung) and EUR (Einnahmen/Überschuss Rechnung).

The report uses the report generator and supports multiple comparison date periods, optional display of individual
accounts and CSV export. Numeric aggregation is performed by L</get_report_data> and helper functions.

In contrast to the old controller I choose to translate the naming in the code, e.g. "Swiss Income Statement" instead
of "Erfolgsrechnung". However in places that go along with existing code or database entries I choose to keep the naming
similar to the existing, e.g. the new column in the table chart is named pos_er_detailed similar to the existing column
pos_er.

=head1 FEATURES

=over 4

=item * Multiple date periods for side-by-side comparison

=item * Group and category subtotals as defined in the database

=item * Optional display of individual account rows

=item * CSV export and HTML rendering

=item * PDF export is disabled by default, the pdf generated by the report generator does not look good,
  however printing from the web page, via icon top left, does look good and should be used instead

=back

=head1 CAVEATS / TODO

=over 4

=item * Add unit test for C<get_report_data> to ensure calculation correctness,
  it would be nice to have a unit test for this however currently we don't have
  a database test setup for the swiss account charts, so this would require significant
  additional work

=item * Generating reports for selected projects is currently not implemented

=back

=head1 BUGS

None known.

=head1 AUTHOR

Cem Aydin E<lt>cem.aydin@revamp-it.chE<gt>

=cut
