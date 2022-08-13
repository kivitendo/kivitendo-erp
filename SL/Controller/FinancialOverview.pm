package SL::Controller::FinancialOverview;

use strict;
use parent qw(SL::Controller::Base);

use List::MoreUtils qw(none);
use List::Util qw(min);

use SL::DB::Employee;
use SL::DB::Invoice;
use SL::DB::Order;
use SL::DB::PeriodicInvoicesConfig;
use SL::DB::PurchaseInvoice;
use SL::DBUtils;
use SL::Controller::Helper::ReportGenerator;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(report number_columns year current_year objects subtotals_per_quarter salesman_id) ],
  'scalar --get_set_init' => [ qw(employees types data show_costs) ],
);

__PACKAGE__->run_before(sub { $::auth->assert('report'); });

sub action_list {
  my ($self) = @_;

  $self->$_($::form->{$_}) for qw(subtotals_per_quarter salesman_id);

  $self->get_objects;
  $self->calculate_one_time_data;
  $self->calculate_periodic_invoices;
  $self->calculate_costs if $self->show_costs;
  $self->prepare_report;
  $self->list_data;
}

# private functions

sub prepare_report {
  my ($self)      = @_;

  $self->report(SL::ReportGenerator->new(\%::myconfig, $::form));

  my @columns = (qw(year quarter month), @{ $self->types });

  $self->number_columns([ grep { !m/^(?:month|year|quarter)$/ } @columns ]);

  my %column_defs          = (
    month                  => { text => t8('Month')                  },
    year                   => { text => t8('Year')                   },
    quarter                => { text => t8('Quarter')                },
    sales_quotations       => { text => t8('Sales Quotations')       },
    sales_orders           => { text => t8('Sales Orders Advance')   },
    sales_orders_per_inv   => { text => t8('Total Sales Orders Value') },
    sales_invoices         => { text => t8('Invoices')               },
    requests_for_quotation => { text => t8('Requests for Quotation') },
    purchase_orders        => { text => t8('Purchase Orders')        },
    purchase_invoices      => { text => t8('Purchase Invoices')      },
    costs                  => { text => t8('Costs')                  },
  );

  $column_defs{$_}->{align} = 'right' for @columns;

  $self->report->set_options(
    std_column_visibility => 1,
    controller_class      => 'FinancialOverview',
    output_format         => 'HTML',
    raw_top_info_text     => $self->render('financial_overview/report_top', { output => 0 }, YEARS_TO_LIST => [ reverse(($self->current_year - 10)..($self->current_year + 5)) ]),
    title                 => t8('Financial overview for #1', $self->year),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );
  $self->report->set_columns(%column_defs);
  $self->report->set_column_order(@columns);
  $self->report->set_export_options(qw(list year subtotals_per_quarter salesman_id));
  $self->report->set_options_from_form;
}

sub get_objects {
  my ($self) = @_;

  $self->current_year(DateTime->today->year);
  $self->year($::form->{year} || DateTime->today->year);

  my $start       = DateTime->new(year => $self->year, month => 1, day => 1);
  my $end         = DateTime->new(year => $self->year, month => 12, day => 31);

  my @f_date      = (transdate => { ge => $start }, transdate => { le => $end });
  my @f_salesman  = $self->salesman_id ? (salesman_id => $self->salesman_id) : ();

  $self->objects({
    sales_quotations       => SL::DB::Manager::Order->get_all(          where => [ and => [ @f_date, @f_salesman, SL::DB::Manager::Order->type_filter('sales_quotation')   ]]),
    sales_orders           => SL::DB::Manager::Order->get_all(          where => [ and => [ @f_date, @f_salesman, SL::DB::Manager::Order->type_filter('sales_order')       ]], with_objects => [ qw(periodic_invoices_config) ]),
    sales_orders_per_inv   => [],
    requests_for_quotation => SL::DB::Manager::Order->get_all(          where => [ and => [ @f_date, @f_salesman, SL::DB::Manager::Order->type_filter('request_quotation') ]]),
    purchase_orders        => SL::DB::Manager::Order->get_all(          where => [ and => [ @f_date, @f_salesman, SL::DB::Manager::Order->type_filter('purchase_order')    ]]),
    sales_invoices         => SL::DB::Manager::Invoice->get_all(        where => [ and => [ @f_date, @f_salesman, ]]),
    purchase_invoices      => SL::DB::Manager::PurchaseInvoice->get_all(where => [ and =>  \@f_date ]),
    periodic_invoices_cfg  => SL::DB::Manager::PeriodicInvoicesConfig->get_all(where => [ active => 1, $self->salesman_id ? ('order.salesman_id' => $self->salesman_id) : () ], with_objects => [ qw(order) ]),
  });

  $self->objects->{sales_orders} = [ grep { !$_->periodic_invoices_config || !$_->periodic_invoices_config->active } @{ $self->objects->{sales_orders} } ];
}

sub init_show_costs { $::instance_conf->get_profit_determination eq 'balance' }

sub init_types {
  my ($self) = @_;
  my @types  = qw(sales_quotations sales_orders sales_orders_per_inv sales_invoices requests_for_quotation purchase_orders purchase_invoices);
  push @types, 'costs' if $self->show_costs;

  return \@types;
}

sub init_data {
  my ($self) = @_;

  my %data  = (
    year    => [ ($self->year) x 12                   ],
    month   => [ (1..12)                              ],
    quarter => [ (1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4) ],
    map {
      $_ => {
        months   => [ (0) x 12 ],
        quarters => [ (0) x  4 ],
        year     => 0,
      }
    } @{ $self->types },
  );

  return \%data;
}

sub calculate_one_time_data {
  my ($self) = @_;

  foreach my $type (@{ $self->types }) {
    my $src_object_type = $type eq 'sales_orders_per_inv' ? 'sales_orders' : $type;
    foreach my $object (@{ $self->objects->{ $src_object_type } || [] }) {
      my $month                              = $object->transdate->month - 1;
      my $tdata                              = $self->data->{$type};

      $tdata->{months}->[$month]            += $object->netamount_base_currency;
      $tdata->{quarters}->[int($month / 3)] += $object->netamount_base_currency;
      $tdata->{year}                        += $object->netamount_base_currency;
    }
  }
}

sub calculate_periodic_invoices {
  my ($self)     = @_;

  my $start_date = DateTime->new(year => $self->year, month =>  1, day =>  1, time_zone => $::locale->get_local_time_zone);
  my $end_date   = DateTime->new(year => $self->year, month => 12, day => 31, time_zone => $::locale->get_local_time_zone);

  $self->calculate_one_periodic_invoice(config => $_, start_date => $start_date, end_date => $end_date) for @{ $self->objects->{periodic_invoices_cfg} };
}

sub calculate_one_periodic_invoice {
  my ($self, %params) = @_;

  # Calculate sales order advance
  my $net  = $params{config}->order->netamount * $params{config}->get_billing_period_length / $params{config}->get_order_value_period_length;
  my $sord = $self->data->{sales_orders};

  foreach my $date ($params{config}->calculate_invoice_dates(start_date => $params{start_date}, end_date => $params{end_date}, past_dates => 1)) {
    $sord->{months  }->[ $date->month   - 1 ] += $net;
    $sord->{quarters}->[ $date->quarter - 1 ] += $net;
    $sord->{year}                             += $net;
  }

  # Calculate total sales order value
  my $date = $params{config}->order->transdate;
  return if $date->year != $params{start_date}->year;

  $net                                       = $params{config}->order->netamount;
  $sord                                      = $self->data->{sales_orders_per_inv};
  $sord->{months  }->[ $date->month   - 1 ] += $net;
  $sord->{quarters}->[ $date->quarter - 1 ] += $net;
  $sord->{year}                             += $net;
}

sub calculate_costs {
  my ($self) = @_;

  # Relevante BWA-Positionen für Kosten:
  #  4 – Mat./Wareneinkauf
  # 10 – Personalkosten
  # 11 – Raumkosten
  # 12 – Betriebl.Steuern
  # 13 – Versicherungsbeiträge
  # 14 – KFZ-Kosten ohne Steuern
  # 15 – Werbe-/Reisekosten
  # 16 – Kosten Warenabgabe
  # 17 – Abschreibungen
  # 18 – Reparatur/Instandhaltung
  # 20 – Sonstige Kosten
  my $query = <<SQL;
    SELECT SUM(ac.amount * chart_category_to_sgn(c.category)) AS amount,
      EXTRACT(month FROM ac.transdate) AS month
    FROM acc_trans ac
    LEFT JOIN chart c ON (c.id = ac.chart_id)
    WHERE (c.pos_bwa IN (4, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20))
      AND (ac.transdate >= ?)
      AND (ac.transdate <  ?)
    GROUP BY month
SQL

  my @args = (
    DateTime->new_local(day => 1, month => 1, year => $self->year)->to_kivitendo,
    DateTime->new_local(day => 1, month => 1, year => $self->year + 1)->to_kivitendo,
  );

  my @results = selectall_hashref_query($::form, SL::DB::AccTransaction->new->db->dbh, $query, @args);
  foreach my $row (@results) {
    my $month                              = $row->{month} - 1;
    my $tdata                              = $self->data->{costs};

    $tdata->{months}->[$month]            += $row->{amount};
    $tdata->{quarters}->[int($month / 3)] += $row->{amount};
    $tdata->{year}                        += $row->{amount};
  }
}

sub list_data {
  my ($self)           = @_;

  my @visible_columns  = $self->report->get_visible_columns;
  my @type_columns     = @{ $self->types };
  my @non_type_columns = grep { my $c = $_; none { $c eq $_ } @type_columns } @visible_columns;

  for my $month (1..12) {
    my %data  = (
      map({ ($_ => { data => $self->data->{$_}->[$month - 1]                                                    }) } @non_type_columns),
      map({ ($_ => { data => $::form->format_amount(\%::myconfig, $self->data->{$_}->{months}->[$month - 1], 2) }) } @type_columns    ),
    );

    $self->report->add_data(\%data);

    if ($self->subtotals_per_quarter && (($month % 3) == 0)) {
      my %subtotal =  (
        year       => { data => $self->year },
        month      => { data => $::locale->text('Total') },
        map { ($_ => { data => $::form->format_amount(\%::myconfig, $self->data->{$_}->{quarters}->[int(($month - 1) / 3)], 2) }) } @type_columns,
      );

      $subtotal{$_}->{class} = 'listsubtotal' for @visible_columns;

      $self->report->add_data(\%subtotal);
    }
  }

  my %data  =  (
    year    => { data => $self->year },
    quarter => { data => $::locale->text('Total') },
    map { ($_ => { data => $::form->format_amount(\%::myconfig, $self->data->{$_}->{year}, 2) }) } @type_columns,
  );

  $data{$_}->{class} = 'listtotal' for @visible_columns;

  $self->report->add_data(\%data);

  return $self->report->generate_with_headers;
}

sub init_employees { SL::DB::Manager::Employee->get_all_sorted }

1;
