package SL::Controller::IncomeStatementChDetailed;

use strict;
use parent qw(SL::Controller::Base);

use POSIX qw(strftime);

use SL::DBUtils;
use SL::DB::Chart;
use SL::DB::Department;
use SL::DB::IncomeStatementChDetailedGroups;
use SL::DB::IncomeStatementChDetailedCategories;

use SL::ReportGenerator;
use SL::Controller::Helper::ReportGenerator; # for PDF and CSV export
use SL::Locale::String; # for t8()
use SL::Presenter::DatePeriodAdder qw(get_date_periods get_hidden_variables_for_report);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(title report date_periods show_accounts include_zero_amounts department_id) ],
  'scalar --get_set_init' => [ qw(departments) ],
);

__PACKAGE__->run_before(sub { $::auth->assert('report'); });

# actions

sub action_report_settings {
  my ($self) = @_;

  $self->setup_report_settings_action_bar;
  $self->render('income_statement_ch_detailed/report_settings', title => t8('Detailed Swiss Income Statement'));
}

sub action_list {
  my ($self) = @_;

  $self->title(t8('Detailed Swiss Income Statement'));

  ### get and validate form parameters

  # get date periods
  $self->date_periods(get_date_periods($::form, 'dateperiod'));

  # simple date validation
  for my $date_period (@{ $self->date_periods }) {
    if (!$date_period->{from} || !$date_period->{to}) {
      $::form->error(t8('Invalid date period specified.'));
    }
    if ($date_period->{from} gt $date_period->{to}) {
      $::form->error(t8('Invalid date period specified: From date is after To date.'));
    }
  }

  $self->show_accounts($::form->{show_accounts} ? 1 : 0);
  $self->include_zero_amounts($::form->{include_zero_amounts} ? 1 : 0);

  $self->department_id($::form->{department_id} || undef);

  ### prepare report
  $self->prepare_report;

  ### get report data and generate report
  my $report_data = $self->get_report_data;
  $self->report->add_data($report_data);

  $self->report->generate_with_headers;
}

# report preparation

sub prepare_report {
  my ($self) = @_;

  ### setup report generator

  $self->report(SL::ReportGenerator->new(\%::myconfig, $::form));

  my @columns     = qw(account description);
  # dynamically create columns for the balance depending on the date periods selected
  my @balance_columns = map { "balance_$_->{index}" } @{ $self->date_periods };
  @columns        = (@columns, @balance_columns);

  # NOTE: the contents of the header are set in set_report_custom_headers,
  # it seems that column definitions are still needed for things to work tho
  my %column_defs = (
    account   => {},
    description => {},
  );
  $column_defs{"balance_$_->{index}"} = {} for (@{ $self->date_periods });

  # NOTE: the pdf export does not look very good, so disabling it for now,
  # printing from the web page does look good and can be used instead
  $self->report->set_options(
    std_column_visibility => 1,
    controller_class      => 'IncomeStatementChDetailed',
    output_format         => 'HTML',
    title                 => $self->title,
    allow_pdf_export      => 0,
    allow_csv_export      => 1,
    allow_chart_export    => 1,
    attachment_basename   => t8('income_statement_ch_detailed') . strftime('_%Y%m%d', localtime time),
    top_info_text         => $self->get_top_info_text,
  );
  $self->report->set_columns(%column_defs);
  $self->report->set_column_order(@columns);

  $self->set_report_custom_headers();

  my @hidden_variables = get_hidden_variables_for_report($::form, 'dateperiod');

  $self->report->set_export_options(qw(list), @hidden_variables, qw(show_accounts include_zero_amounts));
  $self->report->set_options_from_form;
}

sub set_report_custom_headers {
  my ($self) = @_;

  ### this set the date periods in the header as well as the column descriptions

  my @custom_headers = ();
  push @custom_headers, [
    { text => "", },
    { text => "", },
    map {{ text => ($_->{from}//'') . " - " . ($_->{to}//'') }} @{ $self->date_periods },
  ];

  push @custom_headers, [
    { text => t8('Account'), },
    { text => t8('Description'), },
    map {{ text => t8('Saldo'), align => 'right' }} @{ $self->date_periods },
  ];
  $self->report->set_custom_headers(@custom_headers);
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
        if ($self->show_accounts && (has_nonzero_amount(@account_totals) || $self->include_zero_amounts)) {
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

# helper

sub get_top_info_text {
  my ($self) = @_;
  my @text;
  push @text, join " ", t8('Report date:'), $::locale->format_date_object(DateTime->now_local);
  push @text, join " ", t8('Company:'), $::instance_conf->get_company;
  if ($self->department_id) {
    my ($department_ref) = grep { $_->[0] == $self->department_id } @{ $self->departments };
    push @text, $::locale->text('Department') . ": $department_ref->[1]";
  }
  return join "\n", @text;
}

sub insert_description_columns {
  my ($self, $data, $account, $description, $class) = @_;
  $data->{account} = {
    data  => $account,
    class => $class // '',
  };
  $data->{description} = {
    data  => $description,
    class => $class // '',
  };
}

sub insert_date_period_columns_data {
  my ($self, $data, $columns_data, $class) = @_;

  for my $date_period (@{ $self->date_periods }) {
    $data->{"balance_$date_period->{index}"} = {
      data  => $::form->format_amount(\%::myconfig, $columns_data->[ $date_period->{index} ], 2),
      class => $class,
    };
  }
}

sub get_account_totals {
  my ($self, $account) = @_;

  my @account_totals = map { 0.0 } @{ $self->date_periods };

  for my $date_period (@{ $self->date_periods }) {
    # NOTE: this uses SL::DB::Chart::get_balance
    my $account_sum = $account->get_balance(
      fromdate => $date_period->{from_dateobj},
      todate   => $date_period->{to_dateobj},
      department_id => $self->department_id,
    );

    $account_totals[ $date_period->{index} ] += $account_sum;
  }
  return @account_totals;
}

sub has_nonzero_amount {
  my @account_totals = @_;
  return 1 if grep { $_ != 0.0 } @account_totals;
  return 0;
}

# action bar

sub setup_report_settings_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Show'),
        submit    => [ '#report_settings', { action => 'IncomeStatementChDetailed/list' } ],
        accesskey => 'enter',
      ],
    );
  }
}

# initializers

sub init_departments {
  my ($self) = @_;

  my @departments = map {
    [
      $_->id,
      $_->description,
      0,
    ]
  } @{ SL::DB::Manager::Department->get_all_sorted };

  # add empty option
  unshift @departments, [ '', '-- ' . t8('All') . ' --', 1 ];

  \@departments;
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
