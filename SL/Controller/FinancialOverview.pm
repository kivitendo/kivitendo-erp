package SL::Controller::FinancialOverview;

use strict;
use parent qw(SL::Controller::Base);

use List::MoreUtils qw(none);

use SL::DB::Invoice;
use SL::DB::Order;
use SL::DB::PurchaseInvoice;
use SL::Controller::Helper::ReportGenerator;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(report number_columns year current_year types objects data subtotals_per_quarter) ],
);

__PACKAGE__->run_before(sub { $::auth->assert('report'); });

sub action_list {
  my ($self) = @_;

  $self->subtotals_per_quarter($::form->{subtotals_per_quarter});

  $self->get_objects;
  $self->calculate_data;
  $self->prepare_report;
  $self->list_data;
}

# private functions

sub prepare_report {
  my ($self)      = @_;

  $self->report(SL::ReportGenerator->new(\%::myconfig, $::form));

  my @columns = qw(year quarter month sales_quotations sales_orders sales_invoices requests_for_quotation purchase_orders purchase_invoices);

  $self->number_columns([ grep { !m/^(?:month|year|quarter)$/ } @columns ]);

  my %column_defs          = (
    month                  => { text => t8('Month')                  },
    year                   => { text => t8('Year')                   },
    quarter                => { text => t8('Quarter')                },
    sales_quotations       => { text => t8('Sales Quotations')       },
    sales_orders           => { text => t8('Sales Orders')           },
    sales_invoices         => { text => t8('Invoices')               },
    requests_for_quotation => { text => t8('Requests for Quotation') },
    purchase_orders        => { text => t8('Purchase Orders')        },
    purchase_invoices      => { text => t8('Purchase Invoices')      },
  );

  map { $column_defs{$_}->{align} = 'right' } @columns;

  $self->report->set_options(
    std_column_visibility => 1,
    controller_class      => 'FinancialOverview',
    output_format         => 'HTML',
    raw_top_info_text     => $self->render('financial_overview/report_top', { output => 0 }, YEARS_TO_LIST => [ reverse(2000..$self->current_year) ]),
    title                 => t8('Financial overview for #1', $self->year),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );
  $self->report->set_columns(%column_defs);
  $self->report->set_column_order(@columns);
  $self->report->set_export_options(qw(list year subtotals_per_quarter));
  $self->report->set_options_from_form;
}

sub get_objects {
  my ($self) = @_;

  $self->current_year(DateTime->today->year);
  $self->year($::form->{year} || DateTime->today->year);

  my $start       = DateTime->new(year => $self->year, month => 1, day => 1);
  my $end         = DateTime->new(year => $self->year, month => 12, day => 31);

  my @date_filter = (and => [ transdate => { ge => $start }, transdate => { le => $end } ]);

  $self->objects({
    sales_quotations       => SL::DB::Manager::Order->get_all(          where => [ and => [ @date_filter, SL::DB::Manager::Order->type_filter('sales_quotation')   ]]),
    sales_orders           => SL::DB::Manager::Order->get_all(          where => [ and => [ @date_filter, SL::DB::Manager::Order->type_filter('sales_order')       ]]),
    requests_for_quotation => SL::DB::Manager::Order->get_all(          where => [ and => [ @date_filter, SL::DB::Manager::Order->type_filter('request_quotation') ]]),
    purchase_orders        => SL::DB::Manager::Order->get_all(          where => [ and => [ @date_filter, SL::DB::Manager::Order->type_filter('purchase_order')    ]]),
    sales_invoices         => SL::DB::Manager::Invoice->get_all(        where => \@date_filter),
    purchase_invoices      => SL::DB::Manager::PurchaseInvoice->get_all(where => \@date_filter),
  });
}

sub calculate_data {
  my ($self) = @_;

  $self->types([ qw(sales_quotations sales_orders sales_invoices requests_for_quotation purchase_orders purchase_invoices) ]);

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

  foreach my $type (keys %{ $self->objects }) {
    foreach my $object (@{ $self->objects->{ $type } }) {
      my $month                              = $object->transdate->month - 1;
      my $tdata                              = $data{$type};

      $tdata->{months}->[$month]            += $object->netamount;
      $tdata->{quarters}->[int($month / 3)] += $object->netamount;
      $tdata->{year}                        += $object->netamount;
    }
  }

  $self->data(\%data);
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

1;
