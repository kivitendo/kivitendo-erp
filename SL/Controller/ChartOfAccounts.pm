package SL::Controller::ChartOfAccounts;

use strict;
use parent qw(SL::Controller::Base);

use POSIX qw(strftime);

use SL::CA;

use SL::ReportGenerator;
use SL::Controller::Helper::ReportGenerator;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(report) ],
);

__PACKAGE__->run_before(sub { $::auth->assert('report'); });

sub action_list {
  my ($self) = @_;

  if ( $::instance_conf->get_accounting_method eq 'cash' ) {
    $::form->{method} = "cash";
  }

  $self->prepare_report;
  $self->set_report_data;
  $self->report->generate_with_headers;
}

# private functions

sub prepare_report {
  my ($self) = @_;

  $self->report(SL::ReportGenerator->new(\%::myconfig, $::form));

  my @columns     = qw(accno description debit credit);
  my %column_defs = (
    accno       => { text => t8('Account') },
    description => { text => t8('Description') },
    debit       => { text => t8('Debit') },
    credit      => { text => t8('Credit') },
  );

  $self->report->set_options(
    std_column_visibility => 1,
    controller_class      => 'ChartOfAccounts',
    output_format         => 'HTML',
    title                 => t8('Chart of Accounts'),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
    attachment_basename   => t8('chart_of_accounts') . strftime('_%Y%m%d', localtime time),
  );
  $self->report->set_columns(%column_defs);
  $self->report->set_column_order(@columns);

  $self->report->set_export_options(qw(list));
  $self->report->set_options_from_form;
  $self->report->set_sort_indicator($::form->{sort}, 1);
}

sub set_report_data {
  my ($self) = @_;

  my $debit_sum = 0.;
  my $credit_sum = 0.;

  # i tried to use the get_balance function from SL::DB::Manager::Chart here,
  # but the results i got were different (numbers and defined balance/amount),
  # the database queries in CA are more sophisticated, therefore i'm still using these for now,
  # also performance wise they seem faster
  CA->all_accounts(\%::myconfig, \%$::form);

  my $formatted_zero = $::form->format_amount(\%::myconfig, 0., 2);

  for my $chart (@{ $::form->{CA} }) {
    my $balance = $chart->{amount};

    my $link = "controller.pl?action=ListTransactions%2freport_settings&accno=$chart->{accno}&link=1";
    if (defined($balance)) {
      my %data = (
        accno       => { data => $chart->{accno}, link => $link },
        description => { data => $chart->{description} },
        debit       => { data => $balance < 0 ? $::form->format_amount(\%::myconfig, $balance * -1., 2) : ''},
        credit      => { data => $balance >= 0 ? $::form->format_amount(\%::myconfig, $balance, 2) : ''},
      );
      $data{$_}->{align} = 'right' for qw(debit credit);
      map { $data{$_}->{class} = 'listheading' } keys %data if ($chart->{charttype} eq "H") ;
      $self->report->add_data(\%data);

      if ($balance < 0) {
        $debit_sum += $balance;
      } else {
        $credit_sum += $balance;
      }
    }
  }
  my %data_total = (
    accno       => { data => t8('Total') },
    description => { data => '' },
    debit       => { data => $::form->format_amount(\%::myconfig, $debit_sum * -1., 2)},
    credit      => { data => $::form->format_amount(\%::myconfig, $credit_sum, 2)},
  );
  $data_total{$_}->{align} = 'right' for qw(debit credit);
  $data_total{$_}->{class} = 'listtotal' for keys %data_total;

  $self->report->add_data(\%data_total);
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::ChartOfAccounts - Controller for the chart of accounts report

=head1 SYNOPSIS

New controller for Reports -> Chart of Accounts.

This replaces the old bin/mozilla/ca.pl chart_of_accounts sub.

The rest of the functions from ca.pl are separated into the new ListTransactions.pm
controller.

=head1 DESCRIPTION

Displays a list of all accounts with their balance.

Clicking on an account number will open the form for Reports -> List Transactions, with
the account number preselected.

Export to PDF, CSV and Chart is possible.

=head1 CAVEATS / TODO

Database queries are still from SL::CA.

I tried to use the get_balance function from SL::DB::Manager::Chart here,
but the results i got were different (numbers and defined balance/amount).
The database queries in CA are more sophisticated, therefore i'm still using these for now.
Also performance wise they seem faster.

=head1 BUGS

None yet.

=head1 AUTHOR

Cem Aydin E<lt>cem.aydin@revamp-it.chE<gt>

=cut
