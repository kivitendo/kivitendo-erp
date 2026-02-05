package SL::Controller::IncomeStatementChBase;

use strict;
use parent qw(SL::Controller::Base);

use POSIX qw(strftime);

use SL::DBUtils;
use SL::DB::Department;

use SL::ReportGenerator;
use SL::Controller::Helper::ReportGenerator; # for PDF and CSV export
use SL::Locale::String; # for t8()
use SL::Presenter::DatePeriodAdder qw(get_date_periods get_hidden_variables_for_report);

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(actionname title report date_periods controller_class attachment_basename_prefix department_id) ],
  array => [ qw(additional_hidden_variables) ],
  'scalar --get_set_init' => [ qw(departments) ],
);

__PACKAGE__->run_before(sub { $::auth->assert('report'); });

# report preparation

sub prepare_report {
  my ($self) = @_;

  ### setup report generator

  $self->report(SL::ReportGenerator->new(\%::myconfig, $::form));

  my @columns     = qw(account description);
  # dynamically create columns for the balance depending on the date periods selected
  my @balance_columns = map { "balance_$_->{index}" } @{ $self->date_periods };
  @columns        = (@columns, @balance_columns);

  # NOTE: the contents of the header are set in _set_report_custom_headers,
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
    controller_class      => $self->controller_class,
    output_format         => 'HTML',
    title                 => $self->title,
    allow_pdf_export      => 0,
    allow_csv_export      => 1,
    allow_chart_export    => 1,
    attachment_basename   => $self->attachment_basename_prefix . strftime('_%Y%m%d', localtime time),
    top_info_text         => $self->_get_top_info_text,
  );
  $self->report->set_columns(%column_defs);
  $self->report->set_column_order(@columns);

  $self->_set_report_custom_headers();

  my @hidden_variables = get_hidden_variables_for_report($::form, 'dateperiod');

  $self->report->set_export_options(qw(list), @hidden_variables, $self->additional_hidden_variables);
  $self->report->set_options_from_form;
}

sub _set_report_custom_headers {
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

# helper

sub validate_date_periods {
  my ($self) = @_;
  # simple date validation
  for my $date_period (@{ $self->date_periods }) {
    if (!$date_period->{from} || !$date_period->{to}) {
      $::form->error(t8('Invalid date period specified.'));
    }
    if ($date_period->{from} gt $date_period->{to}) {
      $::form->error(t8('Invalid date period specified: From date is after To date.'));
    }
  }
}

sub _get_top_info_text {
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
  my ($self, @account_totals) = @_;
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
        submit    => [ '#report_settings', { action => $self->actionname } ],
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

SL::Controller::IncomeStatementChBase - Base class for the Swiss Income Statement (Erfolgsrechnung) report

=head1 SYNOPSIS

Base class for common functionality.

=head1 DESCRIPTION

See the implementation classes for detailed descriptions.

- SL::Controller::IncomeStatementChSimple
- SL::Controller::IncomeStatementChDetailed

=head1 PUBLIC METHODS

=over 4

=item prepare_report

Sets up the report generator with columns, headers, and export options.

This expects the following attributes to be set in the derived class:

=over 4

=item * title

=item * date_periods

=item * controller_class

=item * attachment_basename_prefix

=item * additional_hidden_variables

=back

=item validate_date_periods

Validates the date periods set in the date_periods attribute.

=item insert_description_columns($data, $account, $description, $class)

Helper to insert the account and description columns into the data hashref.

=item insert_date_period_columns_data($data, $columns_data, $class)

Helper to insert the date period balance columns into the data hashref.

=item get_account_totals($account)

Helper to get the account totals for each date period.

=item has_nonzero_amount(@account_totals)

Helper to check if any of the account totals is non-zero.

=item setup_report_settings_action_bar(%params)

Sets up the action bar for the report settings form.

=back

=head1 BUGS

None known.

=head1 AUTHOR

Cem Aydin E<lt>cem.aydin@revamp-it.chE<gt>

=cut
