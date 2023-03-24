package SL::Controller::ListTransactions;

use strict;
use parent qw(SL::Controller::Base);

use POSIX qw(strftime);
use List::Util qw(first);
use Archive::Zip;

use SL::DB::Chart;
use SL::DB::AccTransaction;
use SL::CA;

use SL::ReportGenerator;
use SL::Controller::Helper::ReportGenerator;
use SL::Locale::String;
use SL::SessionFile::Random;
use SL::Helper::Flash qw(flash);

use SL::Presenter::DatePeriod qw(get_dialog_defaults_from_report_generator
                                  populate_hidden_variables);

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(defaults title account from_date to_date report_type report) ],
  'scalar --get_set_init' => [ qw(accounts_list) ],
);

__PACKAGE__->run_before(sub { $::auth->assert('report'); });

# actions

sub action_report_settings {
  my ($self) = @_;

  $self->set_defaults;

  # if we're coming from a linked entry we want to pre-select the chart picker
  if ($::form->{link}) {
    my $account = first { $_->{accno} eq $::form->{accno} } @{ $self->accounts_list };
    $self->defaults->{chart_id} = $account->{chart_id};
  }

  $self->setup_report_settings_action_bar;
  $self->render('list_transactions/report_settings',
    title => t8('List Transactions'),
    accounts_list => $self->accounts_list,
    defaults => $self->defaults,
  );
}

sub action_list {
  my ($self) = @_;

  $self->set_dates;

  $self->report_type('HTML');

  # set account number from chart picker chart_id
  my $account = first { $_->{chart_id} eq $::form->{chart_id} } @{ $self->accounts_list };
  if (!$account) {
    flash('error', t8('No account selected. Please select an account.'));
    return $self->action_report_settings;
  }
  $::form->{accno} = $account->{accno};

  $self->set_title;

  $self->setup_list_action_bar;
  $self->prepare_report;
  $self->set_report_data;
  $self->report->generate_with_headers;
}

sub action_csv_options_export_all_charts {
  my ($self) = @_;

  $self->set_dates;

  # misusing the set_defaults function here a bit to easily
  # get the values from the form,
  # we have to get the values here because we have to forward them
  # to the csv options form using a hidden array
  $self->set_defaults;

  $self->defaults->{fromdate} = $self->from_date;
  $self->defaults->{todate} = $self->to_date;

  # dialog state is returned in a nested hash, this has to be flattened here
  my @hidden;
  push @hidden, map {
    { key => 'dateperiod_selected_preset_' . $_, value => $self->defaults->{dialog}->{$_} }
  } keys %{ $self->defaults->{dialog} };
  delete($self->defaults->{dialog});

  # handle the rest of the state
  push @hidden, map {
    { key => $_, value => $self->defaults->{$_} }
  } keys %{ $self->defaults };

  $self->setup_csv_options_action_bar;
  $self->render('report_generator/csv_export_options',
    title => t8('CSV export -- options'),
    HIDDEN => \@hidden,
  );
}

sub action_export_all_charts {
  my ($self) = @_;

  my $zip = Archive::Zip->new();

  for my $account (@{ $self->accounts_list }) {
    next if $account->{charttype} eq "H" || !defined($account->{balance});

    $::form->{accno} = $account->{accno};

    my $sfile = SL::SessionFile::Random->new(mode => "w");

    $self->set_title;
    $self->report_type('CSV');

    $self->prepare_report;
    $self->set_report_data;
    $self->report->_generate_csv_content($sfile->fh);
    $sfile->fh->close;

    $zip->addFile(
      $sfile->{file_name},
      t8('list_of_transactions') . "_" . t8('account') . "_" . $account->{accno} . ".csv"
    );
  }

  my $zipfile = SL::SessionFile::Random->new(mode => "w");
  unless ( $zip->writeToFileNamed($zipfile->file_name) == Archive::Zip::AZ_OK ) {
    die 'zipfile write error';
  }
  $zipfile->fh->close;

  $self->send_file(
    $zipfile->file_name,
    type => 'application/zip',
    name => t8('list_of_transactions') . strftime('_%Y%m%d', localtime time) . '.zip',
  );
}

# local functions

sub set_defaults {
  my ($self) = @_;

  # use values from form, then report generator form, then fallback
  my %fallback = (
    #accno         => $self->accounts_list->[0]->{accno},
    chart_id      => '',
    reporttype    => 'custom',
    year          => DateTime->today->year,
    duetyp        => '13',
    dateperiod_from_date => '',
    dateperiod_to_date => '',
    show_subtotals => 0,
    sort          => 'transdate',
  );
  my %defaults;
  for (keys %fallback) {
    $defaults{$_} = $::form->{$_} // $::form->{'report_generator_hidden_' . $_} // $fallback{$_};
  }

  $defaults{dialog} = get_dialog_defaults_from_report_generator('dateperiod');

  $self->defaults(\%defaults);
}

sub set_title {
  my ($self) = @_;
  my $account = first { $_->{accno} eq $::form->{accno} } @{ $self->accounts_list };
  $self->title(join(" ", t8('List Transactions'), t8('Account'), $account->{text}));
}

sub set_dates {
  my ($self) = @_;

  # set dates according to selection
  $self->from_date($::form->{dateperiod_from_date});
  $self->to_date($::form->{dateperiod_to_date});

  # set this into form here for the CA-> routines
  $::form->{fromdate} = $self->from_date;
  $::form->{todate}   = $self->to_date;
  # (no further checks needed, a reasonable error is shown when dates are invalid)
}

sub prepare_report {
  my ($self) = @_;

  $self->report(SL::ReportGenerator->new(\%::myconfig, $::form));

  my @columns     = qw(transdate reference description gegenkonto debit credit ustkonto ustrate balance);
  my %column_defs = (
    transdate   => { text => t8('Date'), },
    reference   => { text => t8('Reference'), },
    description => { text => t8('Description'), },
    debit       => { text => t8('Debit'), },
    credit      => { text => t8('Credit'), },
    gegenkonto  => { text => t8('Gegenkonto'), },
    ustkonto    => { text => t8('USt-Konto'), },
    balance     => { text => t8('Balance'), },
    ustrate     => { text => t8('Satz %'), },
  );

  $self->report->set_options(
    std_column_visibility => 1,
    controller_class      => 'ListTransactions',
    output_format         => $self->report_type,
    title                 => $self->title,
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
    attachment_basename   => t8('list_of_transactions') . strftime('_%Y%m%d', localtime time),
    top_info_text         => $self->get_top_info_text,
  );
  $self->report->set_columns(%column_defs);
  $self->report->set_column_order(@columns);

  my @hidden_variables = qw(accno chart_id show_subtotals sort);
  populate_hidden_variables('dateperiod', \@hidden_variables);

  $self->report->set_export_options(qw(list), @hidden_variables);
  $self->report->set_options_from_form;
  $self->report->set_sort_indicator($::form->{sort}, 1);
  # this is getting triggered but doesn't seem to have an effect
  #$::locale->set_numberformat_wo_thousands_separator(\%::myconfig) if lc($self->report->{options}->{output_format}) eq 'csv';
}

sub set_report_data {
  my ($self) = @_;

  CA->all_transactions(\%::myconfig, \%$::form);

  # this data is used in custom header
  $self->{eb_value} = $::form->{beginning_balance};
  $self->{saldo_old} = $::form->{saldo_old} + $::form->{beginning_balance};
  # "Jahresverkehrszahlen alt"
  $self->{debit_old} = $::form->{old_balance_debit};
  $self->{credit_old} = $::form->{old_balance_credit};

  $self->set_report_custom_headers();

  # initialise totals
  $self->{total_debit} = 0.;
  $self->{total_credit} = 0.;
  my $subtotal_debit = 0.;
  my $subtotal_credit = 0.;
  $self->{balance} = $self->{saldo_old};

  # used for subtotals below
  my $sort_key = $::form->{sort};

  my $idx = 0;
  for my $tr (@{ $::form->{CA} }) {

    # sum up totals
    $self->{total_debit} += $tr->{debit};
    $self->{total_credit} += $tr->{credit};
    $subtotal_debit += $tr->{debit};
    $subtotal_credit += $tr->{credit};
    $self->{balance} -= $tr->{debit};
    $self->{balance} += $tr->{credit};

    # formatting
    my $credit = $tr->{credit} ? $::form->format_amount(\%::myconfig, $tr->{credit}, 2) : '0';
    my $debit = $tr->{debit} ? $::form->format_amount(\%::myconfig, $tr->{debit}, 2) : '0';
    my $ustrate = '';
    if ($tr->{ustrate}) {
      # only format to decimal point when not zero (analog to previous behavior in ca.pl)
      $ustrate = $tr->{ustrate} != 0 ? $::form->format_amount(\%::myconfig, $tr->{ustrate} * 100, 2) : '0';
    }

    my $gegenkonto_string = "";
    foreach my $gegenkonto (@{ $tr->{GEGENKONTO} }) {
      if ($gegenkonto_string eq "") {
        $gegenkonto_string = $gegenkonto->{accno};
      } else {
        $gegenkonto_string .= ", " . $gegenkonto->{accno};
      }
    }

    my $reference_link = "$tr->{module}.pl?action=edit&id=$tr->{id}";

    my %data = (
      transdate   => { data => $tr->{transdate}, },
      reference   => { data => $tr->{reference}, link => $reference_link },
      description => { data => $tr->{description}, },
      gegenkonto  => { data => $gegenkonto_string, },
      debit       => { data => $debit },
      credit      => { data => $credit },
      ustkonto    => { data => $tr->{ustkonto}, },
      ustrate     => { data => $ustrate },
      balance     => { data => $::form->format_amount(\%::myconfig, $self->{balance}, 2, 'DRCR') },
    );
    $data{$_}->{align} = 'right' for qw(debit credit ustkonto ustrate balance);
    # use a row set here in order to keep the table coloring intact
    my @row_set;
    push @row_set, \%data;

    # show subtotals if setting enabled and ( last element reached or
    # next element has a different value in the field selected by sort key )
    if ( ($::form->{show_subtotals}) &&
      ( ($idx == scalar @{ $::form->{CA} } - 1) ||
        ($tr->{$sort_key} ne $::form->{CA}->[$idx + 1]->{$sort_key}) ) ) {

      my %data = map { $_ => { class => 'listtotal' } } keys %{ $self->report->{columns} };
      $data{credit}->{data} = $::form->format_amount(\%::myconfig, $subtotal_credit, 2);
      $data{debit}->{data} = $::form->format_amount(\%::myconfig, $subtotal_debit, 2);
      $data{$_}->{align} = 'right' for qw(debit credit);
      push @row_set, \%data;

      $subtotal_credit = 0.;
      $subtotal_debit = 0.;
    }
    $self->report->add_data(\@row_set);
    $idx++;
  }

  # debit credit and balance totals line
  my %data = map { $_ => { class => 'listtotal' } } keys %{ $self->report->{columns} };
  $data{credit}->{data} = $::form->format_amount(\%::myconfig, $self->{total_credit}, 2);
  $data{debit}->{data} = $::form->format_amount(\%::myconfig, $self->{total_debit}, 2);
  $data{balance}->{data} = $::form->format_amount(\%::myconfig, $self->{balance}, 2, 'DRCR');
  $data{$_}->{align} = 'right' for qw(debit credit balance);
  $self->report->add_data(\%data);

  # get data for the footer line from the CA->all_transactions request
  $self->{saldo_new} = $::form->{saldo_new} + $::form->{beginning_balance};
  # "Jahresverkehrszahlen neu"
  $self->{debit_new} = $::form->{current_balance_debit};
  $self->{credit_new} = $::form->{current_balance_credit};

  $self->set_report_footer_lines();
}

sub set_report_footer_lines {
  my ($self) = @_;
  # line 1
  my %data = map { $_ => { class => 'listtotal' } } keys %{ $self->report->{columns} };
  $data{reference}->{data} = t8('EB-Wert');
  $data{description}  = { data => t8('Saldo neu'), class => 'listtotal', colspan => 2 };
  $data{debit}        = { data => t8('Jahresverkehrszahlen neu'), class => 'listtotal', colspan => 2 };
  $self->report->add_data(\%data);

  # line 2
  my %data2 = map { $_ => { class => 'listtotal' } } keys %{ $self->report->{columns} };
  $data2{reference}->{data} = format_debit_credit($self->{eb_value});
  $data2{description} = { data => format_debit_credit($self->{saldo_new}), class => 'listtotal', colspan => 2 };
  $data2{debit}->{data} = $::form->format_amount(\%::myconfig, abs($self->{debit_new}) , 2) . " S";
  $data2{credit}->{data} = $::form->format_amount(\%::myconfig, $self->{credit_new}, 2) . " H";
  $self->report->add_data(\%data2);
}

sub set_report_custom_headers {
  my ($self) = @_;

  my @custom_headers = ();
  # line 1
  push @custom_headers, [
    { text => t8('Letzte Buchung'), },
    { text => t8('EB-Wert'), },
    { text => t8('Saldo alt'), 'colspan' => 2, },
    { text => t8('Jahresverkehrszahlen alt'), 'colspan' => 2, },
    { text => '', 'colspan' => 2, },
  ];
  push @custom_headers, [
    { text => $::form->{last_transaction}, },
    { text => format_debit_credit($self->{eb_value}), },
    { text => format_debit_credit($self->{saldo_old}), 'colspan' => 2, },
    { text => $::form->format_amount(\%::myconfig, abs($self->{debit_old}), 2) . " S", },
    { text => $::form->format_amount(\%::myconfig, $self->{credit_old}, 2) . " H", },
    { text => '', 'colspan' => 2, },
  ];
  # line 2
  # sorting is selected with radio button
  #my $link = "controller.pl?action=ListTransactions%2freport_settings&accno=$::form->{accno}&fromdate=$::form->{fromdate}&todate=$::form->{todate}&show_subtotals=$::form->{show_subtotals}";
  push @custom_headers, [
    { text => t8('Date'), }, # link => $link . "&sort=transdate", },
    { text => t8('Reference'), }, #'link' => $link . "&sort=reference",  },
    { text => t8('Description'), }, #'link' => $link . "&sort=description",  },
    { text => t8('Gegenkonto'), },
    { text => t8('Debit'), },
    { text => t8('Credit'), },
    { text => t8('USt-Konto'), },
    { text => t8('Satz %'), },
    { text => t8('Balance'), },
  ];

  $self->report->set_custom_headers(@custom_headers);
}

# action bar

sub setup_report_settings_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Show'),
        submit    => [ '#report_settings', { action => 'ListTransactions/list' } ],
        accesskey => 'enter',
      ],
      combobox => [
        action => [
          t8('Export'),
        ],
        action => [
          t8('Export all accounts to CSV (ZIP file)'),
          submit => [ '#report_settings', { action => 'ListTransactions/csv_options_export_all_charts' } ],
        ],
      ], # end of combobox "Export"
    );
  }
}

sub setup_csv_options_action_bar {
  my ($self, %params) = @_;
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Export'),
        submit    => [ '#report_generator_form', { action => 'ListTransactions/export_all_charts' } ],
        accesskey => 'enter',
      ],
      action => [
        t8('Back'),
        submit => [ '#report_generator_form', { action => 'ListTransactions/report_settings' } ],
      ],
    );
  }
}

sub setup_list_action_bar {
  my ($self, %params) = @_;
  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Back'),
        submit => [ '#report_generator_form', { action => 'ListTransactions/report_settings' } ],
      ],
    );
  }
}

# helper

sub get_top_info_text {
  my ($self) = @_;
  my @text;
  if ($::form->{department}) {
    my ($department) = split /--/, $::form->{department};
    push @text, $::locale->text('Department') . " : $department";
  }
  if ($::form->{projectnumber}) {
    push @text, $::locale->text('Project Number') . " : $::form->{projectnumber}<br>";
  }
  push @text, join " ", t8('Period:'), $self->from_date, "-", $self->to_date;
  push @text, join " ", t8('Report date:'), $::locale->format_date_object(DateTime->now_local);
  push @text, join " ", t8('Company:'), $::instance_conf->get_company;
  join "\n", @text;
}

sub format_debit_credit {
  my $dc = shift;
  my $formatted_dc  = $::form->format_amount(\%::myconfig, abs($dc), 2) . ' ';
  $formatted_dc    .= ($dc > 0) ? t8('Credit (one letter abbreviation)') : t8('Debit (one letter abbreviation)');
  $formatted_dc;
}

sub init_accounts_list {
  CA->all_accounts(\%::myconfig, \%$::form);
  my @accounts_list = map { {
    text => "$_->{accno} - $_->{description}",
    accno => $_->{accno},
    chart_id => $_->{id},
    balance => $_->{amount},
    charttype => $_->{charttype},
  } } @{ $::form->{CA} };
  \@accounts_list;
}

1;
