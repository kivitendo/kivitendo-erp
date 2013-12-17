package SL::Controller::FinancialControllingReport;

use strict;
use parent qw(SL::Controller::Base);

use List::Util qw(sum);

use SL::DB::Order;
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::Paginated;
use SL::Controller::Helper::Sorted;
use SL::Controller::Helper::ParseFilter;
use SL::Controller::Helper::ReportGenerator;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(db_args flat_filter) ],
);

__PACKAGE__->run_before(sub { $::auth->assert('sales_order_edit'); });

__PACKAGE__->get_models_url_params('flat_filter');
__PACKAGE__->make_paginated(
  MODEL         => 'Order',
  PAGINATE_ARGS => 'db_args',
  ONLY          => [ qw(list) ],
);

__PACKAGE__->make_sorted(
  MODEL                   => 'Order',
  ONLY                    => [ qw(list) ],

  DEFAULT_BY              => 'globalprojectnumber',
  DEFAULT_DIR             => 1,

  ordnumber               => t8('Order'),
  customer                => t8('Customer'),
  transaction_description => t8('Transaction description'),
  globalprojectnumber     => t8('Project'),
  netamount               => t8('Order amount'),
);

sub action_list {
  my ($self) = @_;

  $self->db_args($self->setup_db_args_for_list(filter => $::form->{filter}));
  $self->flat_filter({ map { $_->{key} => $_->{value} } $::form->flatten_variables('filter') });
  $self->make_filter_summary;

  $self->prepare_report;

  $self->{orders} = $self->get_models(%{ $self->db_args });

  $self->calculate_data;

  $self->list_objects;
}

# private functions

sub setup_db_args_for_list {
  my ($self) = @_;

  $self->{filter} = {};
  my %args     = ( parse_filter($::form->{filter}, with_objects => [ 'customer', 'globalproject' ], launder_to => $self->{filter}));
  $args{query} = [
    @{ $args{query} || [] },
    SL::DB::Manager::Order->type_filter('sales_order'),
  ];

  return \%args;
}

sub prepare_report {
  my ($self)      = @_;

  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns     = qw(customer globalprojectnumber ordnumber netamount delivered_amount delivered_amount_p billed_amount billed_amount_p paid_amount paid_amount_p
                       billable_amount billable_amount_p other_amount);
  my @sortable    = qw(ordnumber transdate customer netamount globalprojectnumber);
  $self->{number_columns} = [ qw(netamount billed_amount billed_amount_p delivered_amount delivered_amount_p paid_amount paid_amount_p other_amount billable_amount billable_amount_p) ];

  my %column_defs           = (
    netamount               => {                                                                                         },
    billed_amount           => { text     => $::locale->text('Billed amount')                                            },
    billed_amount_p         => { text     => $::locale->text('%')                                                        },
    delivered_amount        => { text     => $::locale->text('Delivered amount')                                         },
    delivered_amount_p      => { text     => $::locale->text('%')                                                        },
    paid_amount             => { text     => $::locale->text('Paid amount')                                              },
    paid_amount_p           => { text     => $::locale->text('%')                                                        },
    billable_amount         => { text     => $::locale->text('Billable amount')                                          },
    billable_amount_p       => { text     => $::locale->text('%')                                                        },
    other_amount            => { text     => $::locale->text('Billed extra expenses')                                    },
    ordnumber               => { obj_link => sub { $self->link_to($_[0])                                              }  },
    customer                => {      sub => sub { $_[0]->customer->name                                              },
                                 obj_link => sub { $self->link_to($_[0]->customer)                                    }  },
    globalprojectnumber     => {      sub => sub { $_[0]->globalproject_id ? $_[0]->globalproject->projectnumber : '' }  },
  );

  map { $column_defs{$_}->{text} ||= $::locale->text( $self->get_sort_spec->{$_}->{title} ) } keys %column_defs;
  map { $column_defs{$_}->{align} = 'right' } @{ $self->{number_columns} };

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'FinancialControlling',
    output_format         => 'HTML',
    top_info_text         => $::locale->text('Financial controlling report for open sales orders'),
    raw_top_info_text     => $self->render('financial_controlling_report/report_top',    { no_output => 1, partial => 1 }),
    raw_bottom_info_text  => $self->render('financial_controlling_report/report_bottom', { no_output => 1, partial => 1 }),
    title                 => $::locale->text('Financial Controlling Report'),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter));
  $report->set_options_from_form;
  $self->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);

  $self->disable_pagination if $report->{options}{output_format} =~ /^(pdf|csv)$/i;

  $self->{report_data} = {
    column_defs        => \%column_defs,
    columns            => \@columns,
  };
}

sub calculate_data {
  my ($self) = @_;

  foreach my $order (@{ $self->{orders} }) {
    my $delivery_orders = $order->linked_records(direction => 'to', to => 'DeliveryOrder', via => 'Order', query => [ '!customer_id' => undef ]);
    my $invoices        = $order->linked_records(direction => 'to', to => 'Invoice',       via => [ 'Order', 'DeliveryOrder' ]);

    $order->{delivered_amount}  = sum map { $self->sum_relevant_items(order => $order, other => $_, by_order => 1) } @{ $delivery_orders };
    $order->{billed_amount}     = sum map { $self->sum_relevant_items(order => $order, other => $_)                } @{ $invoices        };
    $order->{paid_amount}       = sum map { $_->paid                                                               } @{ $invoices        };
    my $billed_amount           = sum map { $_->netamount                                                          } @{ $invoices        };
    $order->{other_amount}      = $billed_amount             - $order->{billed_amount};
    $order->{billable_amount}   = $order->{delivered_amount} - $order->{billed_amount};

    foreach (qw(delivered billed paid billable)) {
      $order->{"${_}_amount_p"} = $order->netamount * 1 ? $order->{"${_}_amount"} * 100 / $order->netamount : undef;
    }
  }
}

sub sum_items {
  my ($self, %params) = @_;

  my %vals;

  foreach my $item (@{ $params{obj}->items }) {
    $vals{$item->parts_id}            ||= { parts_id => $item->parts_id, amount => 0, base_qty => 0 };
    $vals{$item->parts_id}->{amount}   += $item->qty * $item->sellprice * (1 - $item->discount) / (($item->price_factor * 1) || 1);
    $vals{$item->parts_id}->{base_qty} += $item->qty * $item->unit_obj->base_factor;
  }

  return \%vals;
}

sub sum_relevant_items {
  my ($self, %params) = @_;

  $params{order}->{amounts_by_parts_id} ||= $self->sum_items(obj => $params{order});
  my $sums                                = $self->sum_items(obj => $params{other});
  my $total                               = 0;

  foreach my $item (grep { $params{order}->{amounts_by_parts_id}->{ $_->{parts_id} } } values %{ $sums }) {
    my $order_item = $params{order}->{amounts_by_parts_id}->{ $item->{parts_id} };
    if ($params{by_order} && $order_item->{base_qty}) {
      $total += $order_item->{amount} * $item->{base_qty} / $order_item->{base_qty};
    } else {
      $total += $item->{amount};
    }
  }

  return $total;
}

sub list_objects {
  my ($self)      = @_;
  my $column_defs = $self->{report_data}->{column_defs};

  for my $obj (@{ $self->{orders} || [] }) {
    my %data = map {
      $_ => {
        data => $column_defs->{$_}{sub} ? $column_defs->{$_}{sub}->($obj)
              : $obj->can($_)           ? $obj->$_
              :                           $obj->{$_},
        link => $column_defs->{$_}{obj_link} ? $column_defs->{$_}{obj_link}->($obj) : '',
      },
    } @{ $self->{report_data}{columns} || {} };

    map { $data{$_}->{data} = defined $data{$_}->{data} ? int($data{$_}->{data}) : ''    } grep {  m/_p$/ } @{ $self->{number_columns} };
    map { $data{$_}->{data} = $::form->format_amount(\%::myconfig, $data{$_}->{data}, 2) } grep { !m/_p$/ } @{ $self->{number_columns} };

    $self->{report}->add_data(\%data);
  }

  return $self->{report}->generate_with_headers;
}

sub make_filter_summary {
  my ($self) = @_;

  my $filter = $::form->{filter} || {};
  my @filter_strings;

  my @filters = (
    [ $filter->{"ordnumber:substr::ilike"},                $::locale->text('Number')                                          ],
    [ $filter->{"transdate:date::ge"},                     $::locale->text('Order Date') . " " . $::locale->text('From Date') ],
    [ $filter->{"transdate:date::le"},                     $::locale->text('Order Date') . " " . $::locale->text('To Date')   ],
    [ $filter->{customer}{"name:substr::ilike"},           $::locale->text('Customer')                                        ],
    [ $filter->{customer}{"customernumber:substr::ilike"}, $::locale->text('Customer Number')                                 ],
  );

  $self->{filter_summary} = join ', ', @filter_strings;
}

sub link_to {
  my ($self, $object, %params) = @_;

  return unless $object;
  my $action = $params{action} || 'edit';

  if ($object->isa('SL::DB::Order')) {
    my $type = $object->type;
    my $id   = $object->id;

    return "oe.pl?action=$action&type=$type&vc=customer&id=$id";
  }
  if ($object->isa('SL::DB::Customer')) {
    my $id     = $object->id;
    return "ct.pl?action=$action&id=$id&db=customer";
  }
}

1;
