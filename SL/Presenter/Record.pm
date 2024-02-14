package SL::Presenter::Record;

use strict;

use SL::Presenter;
use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Presenter::Tag qw(html_tag button_tag);

use Exporter qw(import);
our @EXPORT_OK = qw(grouped_record_list empty_record_list record_list record);

use SL::Util;

use Carp;
use List::Util qw(first);

my @ORDERED_TYPES = qw(
  requirement_spec
  shop_order
  sales_quotation
  sales_order_intake
  sales_order
  sales_delivery_order
  rma_delivery_order
  sales_reclamation
  sales_invoice
  ar_transaction
  request_quotation
  purchase_quotation_intake
  purchase_order
  purchase_order_confirmation
  purchase_delivery_order
  supplier_delivery_order
  purchase_reclamation
  purchase_invoice
  ap_transaction
  gl_transaction
  bank_transaction
  sepa_collection
  sepa_transfer
  letter
  email_journal
  dunning
  ar_transaction_template
  ap_transaction_template
  gl_transaction_template
  );

my %TYPE_TO_PARAMS = (
  # sub gets other params as arguments to override if needed
  # has to encoupsulated in a sub for evaluation of locale translations
  requirement_spec => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Requirement specs'),
      type    => 'requirement_spec',
      columns => [
        [ $::locale->text('Requirement spec number'), sub { $_[0]->presenter->requirement_spec(display => 'table-cell') } ],
        [ $::locale->text('Customer'),                'customer'                                                      ],
        [ $::locale->text('Title'),                   'title'                                                         ],
        [ $::locale->text('Project'),                 'project',                                                      ],
        [ $::locale->text('Status'),                  sub { $_[0]->status->description }                              ],
      ],
      %params,
    }
  },
  shop_order => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Shop Orders'),
      type    => 'shop_order',
      columns => [
        [ $::locale->text('Shop Order Date'),         sub { $_[0]->order_date->to_kivitendo }                         ],
        [ $::locale->text('Shop Order Number'),       sub { $_[0]->presenter->shop_order(display => 'table-cell') }   ],
        [ $::locale->text('Transfer Date'),           'transfer_date'                                                 ],
        [ $::locale->text('Amount'),                  'amount'                                                        ],
      ],
      %params,
    }
  },
  sales_quotation => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Sales Quotations'),
      type    => 'sales_quotation',
      columns => [
        [ $::locale->text('Quotation Date'),          'transdate'                                                                ],
        [ $::locale->text('Quotation Number'),        sub { $_[0]->presenter->sales_quotation(display => 'table-cell') }         ],
        [ $::locale->text('Customer'),                'customer'                                                                 ],
        [ $::locale->text('Net amount'),              'netamount'                                                                ],
        [ $::locale->text('Transaction description'), 'transaction_description'                                                  ],
        [ $::locale->text('Project'),                 'globalproject', ],
        [ $::locale->text('Closed'),                  'closed'                                                                   ],
      ],
      %params,
    }
  },
  request_quotation => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Request Quotations'),
      type    => 'request_quotation',
      columns => [
        [ $::locale->text('Quotation Date'),          'transdate'                                                                ],
        [ $::locale->text('Quotation Number'),        sub { $_[0]->presenter->request_quotation(display => 'table-cell') }       ],
        [ $::locale->text('Vendor'),                  'vendor'                                                                   ],
        [ $::locale->text('Net amount'),              'netamount'                                                                ],
        [ $::locale->text('Transaction description'), 'transaction_description'                                                  ],
        [ $::locale->text('Project'),                 'globalproject', ],
        [ $::locale->text('Closed'),                  'closed'                                                                   ],
      ],
      %params,
    }
  },
  purchase_quotation_intake => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Purchase Quotation Intakes'),
      type    => 'purchase_quotation_intake',
      columns => [
        [ $::locale->text('Quotation Date'),          'transdate'                                                                ],
        [ $::locale->text('Quotation Number'),        sub { $_[0]->presenter->purchase_quotation_intake(display => 'table-cell') } ],
        [ $::locale->text('Vendor'),                  'vendor'                                                                   ],
        [ $::locale->text('Net amount'),              'netamount'                                                                ],
        [ $::locale->text('Transaction description'), 'transaction_description'                                                  ],
        [ $::locale->text('Project'),                 'globalproject', ],
        [ $::locale->text('Closed'),                  'closed'                                                                   ],
      ],
      %params,
    }
  },
  sales_order_intake => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Sales Order Intakes'),
      type    => 'sales_order_intake',
      columns => [
        [ $::locale->text('Order Date'),              'transdate'                                                                ],
        [ $::locale->text('Order Number'),            sub { $_[0]->presenter->sales_order_intake(display => 'table-cell') }      ],
        [ $::locale->text('Quotation'),               'quonumber' ],
        [ $::locale->text('Customer'),                'customer'                                                                 ],
        [ $::locale->text('Net amount'),              'netamount'                                                                ],
        [ $::locale->text('Transaction description'), 'transaction_description'                                                  ],
        [ $::locale->text('Project'),                 'globalproject', ],
        [ $::locale->text('Closed'),                  'closed'                                                                   ],
      ],
      %params,
    }
  },
  sales_order => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Sales Orders'),
      type    => 'sales_order',
      columns => [
        [ $::locale->text('Order Date'),              'transdate'                                                                ],
        [ $::locale->text('Order Number'),            sub { $_[0]->presenter->sales_order(display => 'table-cell') }             ],
        [ $::locale->text('Quotation'),               'quonumber' ],
        [ $::locale->text('Customer'),                'customer'                                                                 ],
        [ $::locale->text('Net amount'),              'netamount'                                                                ],
        [ $::locale->text('Transaction description'), 'transaction_description'                                                  ],
        [ $::locale->text('Project'),                 'globalproject', ],
        [ $::locale->text('Closed'),                  'closed'                                                                   ],
      ],
      %params,
    }
  },
  purchase_order => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Purchase Orders'),
      type    => 'purchase_order',
      columns => [
        [ $::locale->text('Order Date'),              'transdate'                                                                ],
        [ $::locale->text('Order Number'),            sub { $_[0]->presenter->purchase_order(display => 'table-cell') }          ],
        [ $::locale->text('Request for Quotation'),   'quonumber' ],
        [ $::locale->text('Vendor'),                  'vendor'                                                                 ],
        [ $::locale->text('Net amount'),              'netamount'                                                                ],
        [ $::locale->text('Transaction description'), 'transaction_description'                                                  ],
        [ $::locale->text('Project'),                 'globalproject', ],
        [ $::locale->text('Closed'),                  'closed'                                                                   ],
      ],
      %params,
    }
  },
  purchase_order_confirmation => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Purchase Order Confirmations'),
      type    => 'purchase_order_confirmation',
      columns => [
        [ $::locale->text('Confirmation Date'),       'transdate'                                                                    ],
        [ $::locale->text('Confirmation Number'),     sub { $_[0]->presenter->purchase_order_confirmation(display => 'table-cell') } ],
        [ $::locale->text('Request for Quotation'),   'quonumber'                                                                    ],
        [ $::locale->text('Vendor'),                  'vendor'                                                                       ],
        [ $::locale->text('Net amount'),              'netamount'                                                                    ],
        [ $::locale->text('Transaction description'), 'transaction_description'                                                      ],
        [ $::locale->text('Project'),                 'globalproject',                                                               ],
        [ $::locale->text('Closed'),                  'closed'                                                                       ],
      ],
      %params,
    }
  },
  sales_delivery_order => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Sales Delivery Orders'),
      type    => 'sales_delivery_order',
      columns => [
        [ $::locale->text('Delivery Order Date'),     'transdate'                                                                ],
        [ $::locale->text('Delivery Order Number'),   sub { $_[0]->presenter->sales_delivery_order(display => 'table-cell') }    ],
        [ $::locale->text('Order Number'),            'ordnumber' ],
        [ $::locale->text('Customer'),                'customer'                                                                 ],
        [ $::locale->text('Transaction description'), 'transaction_description'                                                  ],
        [ $::locale->text('Project'),                 'globalproject', ],
        [ $::locale->text('Delivered'),               'delivered'                                                                ],
        [ $::locale->text('Closed'),                  'closed'                                                                   ],
      ],
      %params,
    }
  },
  rma_delivery_order => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('RMA Delivery Orders'),
      type    => 'rma_delivery_order',
      columns => [
        [ $::locale->text('Delivery Order Date'),     'transdate'                                                                ],
        [ $::locale->text('Delivery Order Number'),   sub { $_[0]->presenter->rma_delivery_order(display => 'table-cell') }    ],
        [ $::locale->text('Order Number'),            'ordnumber' ],
        [ $::locale->text('Customer'),                'customer'                                                                 ],
        [ $::locale->text('Transaction description'), 'transaction_description'                                                  ],
        [ $::locale->text('Project'),                 'globalproject', ],
        [ $::locale->text('Delivered'),               'delivered'                                                                ],
        [ $::locale->text('Closed'),                  'closed'                                                                   ],
      ],
      %params,
    }
  },
  purchase_delivery_order => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Purchase Delivery Orders'),
      type    => 'purchase_delivery_order',
      columns => [
        [ $::locale->text('Delivery Order Date'),     'transdate'                                                                ],
        [ $::locale->text('Delivery Order Number'),   sub { $_[0]->presenter->purchase_delivery_order(display => 'table-cell') } ],
        [ $::locale->text('Order Number'),            'ordnumber' ],
        [ $::locale->text('Vendor'),                  'vendor'                                                                 ],
        [ $::locale->text('Transaction description'), 'transaction_description'                                                  ],
        [ $::locale->text('Project'),                 'globalproject', ],
        [ $::locale->text('Delivered'),               'delivered'                                                                ],
        [ $::locale->text('Closed'),                  'closed'                                                                   ],
      ],
      %params,
    }
  },
  supplier_delivery_order => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Supplier Delivery Orders'),
      type    => 'supplier_delivery_order',
      columns => [
        [ $::locale->text('Delivery Order Date'),     'transdate'                                                                ],
        [ $::locale->text('Delivery Order Number'),   sub { $_[0]->presenter->supplier_delivery_order(display => 'table-cell') } ],
        [ $::locale->text('Order Number'),            'ordnumber' ],
        [ $::locale->text('Vendor'),                  'vendor'                                                                 ],
        [ $::locale->text('Transaction description'), 'transaction_description'                                                  ],
        [ $::locale->text('Project'),                 'globalproject', ],
        [ $::locale->text('Delivered'),               'delivered'                                                                ],
        [ $::locale->text('Closed'),                  'closed'                                                                   ],
      ],
      %params,
    }
  },
  sales_reclamation => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Sales Reclamations'),
      type    => 'sales_reclamation',
      columns => [
        [ $::locale->text('Reclamation Date'),        'transdate'                                                          ],
        [ $::locale->text('Reclamation Number'),      sub { $_[0]->presenter->sales_reclamation(display => 'table-cell') } ],
        [ $::locale->text('Customer'),                'customer'                                                           ],
        [ $::locale->text('Transaction description'), 'transaction_description'                                            ],
        [ $::locale->text('Project'),                 'globalproject',                                                     ],
        [ $::locale->text('Delivered'),               'delivered'                                                          ],
        [ $::locale->text('Closed'),                  'closed'                                                             ],
      ],
      %params,
    }
  },
  purchase_reclamation => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Purchase Reclamations'),
      type    => 'purchase_reclamation',
      columns => [
        [ $::locale->text('Reclamation Date'),        'transdate'                                                          ],
        [ $::locale->text('Reclamation Number'),      sub { $_[0]->presenter->purchase_reclamation(display => 'table-cell') } ],
        [ $::locale->text('Vendor'),                'vendor'                                                           ],
        [ $::locale->text('Transaction description'), 'transaction_description'                                            ],
        [ $::locale->text('Project'),                 'globalproject',                                                     ],
        [ $::locale->text('Delivered'),               'delivered'                                                          ],
        [ $::locale->text('Closed'),                  'closed'                                                             ],
      ],
      %params,
    }
  },
  sales_invoice => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Sales Invoices'),
      type    => 'sales_invoice',
      columns => [
        [ $::locale->text('Invoice Date'),            'transdate'               ],
        [ $::locale->text('Type'),                    sub { $_[0]->displayable_type } ],
        [ $::locale->text('Invoice Number'),          sub { $_[0]->presenter->sales_invoice(display => 'table-cell') } ],
        [ $::locale->text('Quotation Number'),        'quonumber' ],
        [ $::locale->text('Order Number'),            'ordnumber' ],
        [ $::locale->text('Customer'),                'customer'                ],
        [ $::locale->text('Net amount'),              'netamount'               ],
        [ $::locale->text('Paid'),                    'paid'                    ],
        [ $::locale->text('Transaction description'), 'transaction_description' ],
      ],
      %params,
    }
  },
  purchase_invoice => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Purchase Invoices'),
      type    => 'purchase_invoice',
      columns => [
        [ $::locale->text('Invoice Date'),                 'transdate'               ],
        [ $::locale->text('Invoice Number'),               sub { $_[0]->presenter->purchase_invoice(display => 'table-cell') } ],
        [ $::locale->text('Request for Quotation Number'), 'quonumber' ],
        [ $::locale->text('Order Number'),                 'ordnumber' ],
        [ $::locale->text('Vendor'),                       'vendor'                 ],
        [ $::locale->text('Net amount'),                   'netamount'               ],
        [ $::locale->text('Paid'),                         'paid'                    ],
        [ $::locale->text('Transaction description'),      'transaction_description' ],
      ],
      %params,
    }
  },
  ar_transaction => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('AR Transactions'),
      type    => 'ar_transaction',
      columns => [
        [ $::locale->text('Invoice Date'),            'transdate'               ],
        [ $::locale->text('Type'),                    sub { $_[0]->displayable_type } ],
        [ $::locale->text('Invoice Number'),          sub { $_[0]->presenter->ar_transaction(display => 'table-cell') } ],
        [ $::locale->text('Customer'),                'customer'                ],
        [ $::locale->text('Net amount'),              'netamount'               ],
        [ $::locale->text('Paid'),                    'paid'                    ],
        [ $::locale->text('Transaction description'), 'transaction_description' ],
      ],
      %params,
    }
  },
  ap_transaction => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('AP Transactions'),
      type    => 'ap_transaction',
      columns => [
        [ $::locale->text('Invoice Date'),            'transdate'                      ],
        [ $::locale->text('Invoice Number'),          sub { $_[0]->presenter->ap_transaction(display => 'table-cell') } ],
        [ $::locale->text('Vendor'),                  'vendor'                         ],
        [ $::locale->text('Net amount'),              'netamount'                      ],
        [ $::locale->text('Paid'),                    'paid'                           ],
        [ $::locale->text('Transaction description'), 'transaction_description'        ],
      ],
      %params,
    }
  },
  gl_transaction => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('GL Transactions'),
      type    => 'gl_transaction',
      columns => [
        [ $::locale->text('Transdate'),        'transdate'                                                    ],
        [ $::locale->text('Reference'),   'reference'                                                    ],
        [ $::locale->text('Description'), sub { $_[0]->presenter->gl_transaction(display => 'table-cell') } ],
      ],
      %params,
    }
  },
  bank_transaction => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Bank transactions'),
      type    => 'bank_transactions',
      columns => [
        [ $::locale->text('Transdate'),            'transdate'                      ],
        [ $::locale->text('Local Bank Code'),      sub { $_[0]->local_bank_account->presenter->bank_code }  ],
        [ $::locale->text('Local account number'), sub { $_[0]->local_bank_account->presenter->account_number }  ],
        [ $::locale->text('Remote Bank Code'),     'remote_bank_code' ],
        [ $::locale->text('Remote account number'),'remote_account_number' ],
        [ $::locale->text('Valutadate'),           'valutadate' ],
        [ $::locale->text('Amount'),               'amount' ],
        [ $::locale->text('Currency'),             sub { $_[0]->currency->name } ],
        [ $::locale->text('Remote name'),          'remote_name' ],
        [ $::locale->text('Purpose'),              'purpose' ],
      ],
      %params,
    }
  },
  # sepa_export gets called from sepa_transfer and sepa_collection
  sepa_export => sub {
    my (%params) = @_;

    my ($source, $destination) = $params{type} eq 'sepa_transfer' ? qw(our vc)                                 : qw(vc our);
    $params{title}             = $params{type} eq 'sepa_transfer' ? $::locale->text('Bank transfers via SEPA') : $::locale->text('Bank collections via SEPA');
    $params{with_columns}      = [ grep { $_ ne 'record_link_direction' } @{ $params{with_columns} || [] } ];

    delete $params{edit_record_links};

    {
      columns => [
        [ $::locale->text('Export Number'),    'sepa_export',                                  ],
        [ $::locale->text('Execution date'),   'execution_date'                                ],
        [ $::locale->text('Export date'),      sub { $_[0]->sepa_export->itime->to_kivitendo } ],
        [ $::locale->text('Source BIC'),       "${source}_bic"                                 ],
        [ $::locale->text('Source IBAN'),      "${source}_iban"                                ],
        [ $::locale->text('Destination BIC'),  "${destination}_bic"                            ],
        [ $::locale->text('Destination IBAN'), "${destination}_iban"                           ],
        [ $::locale->text('Amount'),           'amount'                                        ],
      ],
      %params,
    }
  },
  sepa_transfer => sub {
    my (%params) = @_;
    my %type_params = _get_type_params('sepa_export', %params, type => 'sepa_transfer');
    return \%type_params;
  },
  sepa_collection => sub {
    my (%params) = @_;
    my %type_params = _get_type_params('sepa_export', %params, type => 'sepa_collection');
    return \%type_params;
  },
  letter => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Letters'),
      type    => 'letter',
      columns => [
        [ $::locale->text('Date'),         'date'                                                ],
        [ $::locale->text('Letternumber'), sub { $_[0]->presenter->letter(display => 'table-cell') } ],
        [ $::locale->text('Customer'),     'customer'                                            ],
        [ $::locale->text('Reference'),    'reference'                                           ],
        [ $::locale->text('Subject'),      'subject'                                             ],
      ],
      %params,
    }
  },
  email_journal => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Email'),
      type    => 'email_journal',
      columns => [
        [ $::locale->text('Sent on'), sub { $_[0]->sent_on->to_kivitendo(precision => 'seconds') } ],
        [ $::locale->text('Subject'), sub { $_[0]->presenter->email_journal(display => 'table-cell') } ],
        [ $::locale->text('Status'),  'status'                                                     ],
        [ $::locale->text('From'),    'from'                                                       ],
        [ $::locale->text('To'),      'recipients'                                                 ],
      ],
      %params,
    }
  },
  dunning => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('Dunnings'),
      type    => 'dunning',
      columns => [
        [ $::locale->text('Dunning Level'),   sub { $_[0]->presenter->dunning(display => 'table-cell') } ],
        [ $::locale->text('Dunning Date'),    'transdate'                                                ],
        [ $::locale->text('Dunning Duedate'), 'duedate'                                                  ],
        [ $::locale->text('Total Fees'),      'fee'                                                      ],
        [ $::locale->text('Interest'),        'interest'                                                 ],
      ],
      %params,
    }
  },
  gl_transaction_template => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('GL Transaction Template'),
      type    => 'gl_transaction_template',
      columns => [
        [ $::locale->text('Name'),                    'template_name_to_use'              ],
        [ $::locale->text('Transaction description'), 'transaction_description',          ],
        [ $::locale->text('Create Date'),              sub { $_[0]->itime->to_kivitendo } ],
        [ $::locale->text('Modification date'),        sub { $_[0]->mtime->to_kivitendo } ],
      ],
      %params,
    }
  },
  ar_transaction_template => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('AR Transaction Template'),
      type    => 'ar_transaction_template',
      columns => [
        [ $::locale->text('Name'),                    'template_name_to_use'             ],
        [ $::locale->text('Customer'),                'customer'                         ],
        [ $::locale->text('Project'),                 'project',                         ],
        [ $::locale->text('Transaction description'), 'transaction_description',         ],
        [ $::locale->text('Create Date'),             sub { $_[0]->itime->to_kivitendo } ],
        [ $::locale->text('Modification date'),       sub { $_[0]->mtime->to_kivitendo } ],
      ],
      %params,
    }
  },
  ap_transaction_template => sub {
    my (%params) = @_;
    {
      title   => $::locale->text('AP Transaction Template'),
      type    => 'ap_transaction_template',
      columns => [
        [ $::locale->text('Name'),                    'template_name_to_use'             ],
        [ $::locale->text('Vendor'),                  'vendor'                           ],
        [ $::locale->text('Project'),                 'project',                         ],
        [ $::locale->text('Transaction description'), 'transaction_description',         ],
        [ $::locale->text('Create Date'),             sub { $_[0]->itime->to_kivitendo } ],
        [ $::locale->text('Modification date'),       sub { $_[0]->mtime->to_kivitendo } ],
      ],
      %params,
    }
  },
);

sub _get_type_params {
  my ($type, %params) = @_;

  my $type_params = $TYPE_TO_PARAMS{$type};
  croak "Unknown type '$type'" unless $type_params;

  return %{$type_params->(%params)};
}

sub _arrayify {
  my ($array) = @_;
  return []     if !defined $array;
  return $array if ref $array;
  return [ $array ];
}

sub record {
  my ($record, %params) = @_;

  my %grouped = _group_records( [ $record ] ); # pass $record as arrayref
  my $type    = (keys %grouped)[0];

  $record->presenter->sales_invoice(   $record, %params) if $type eq 'sales_invoice';
  $record->presenter->purchase_invoice($record, %params) if $type eq 'purchase_invoice';
  $record->presenter->ar_transaction(  $record, %params) if $type eq 'ar_transaction';
  $record->presenter->ap_transaction(  $record, %params) if $type eq 'ap_transaction';
  $record->presenter->gl_transaction(  $record, %params) if $type eq 'gl_transaction';

  return '';
}

sub grouped_record_list {
  my ($list, %params) = @_;

  %params    = map { exists $params{$_} ? ($_ => $params{$_}) : () } qw(edit_record_links with_columns object_id object_model);

  my %groups = _sort_grouped_lists(_group_records($list));
  my $output = '';

  foreach my $type (@ORDERED_TYPES) {
    $output .= record_list($groups{$type}, _get_type_params($type, %params)) if $groups{$type};
  }

  $output  = SL::Presenter->get->render('presenter/record/grouped_record_list', %params, output => $output);

  return $output;
}

sub grouped_list { goto &grouped_record_list }

sub simple_grouped_record_list {
  my ($list, %params) = @_;

  my %groups = _sort_grouped_lists(_group_records($list));
  my $output = '';

  foreach my $type (@ORDERED_TYPES) {
    my $ordered_records = $groups{$type};
    next unless $ordered_records;
    my %type_params = _get_type_params($type, %params);
    my $type_output = html_tag('b', $type_params{title} . ": ");
    $type_output .= join (', ',
      map { $_->presenter->show(%params) }
      @{ $ordered_records }
    );
    $output .= html_tag('div', $type_output);
  }

  return $output;
}

sub empty_record_list {
  my (%params) = @_;
  return grouped_record_list([], %params);
}

sub empty_list { goto &empty_record_list }

sub record_list {
  my ($list, %params) = @_;

  my @columns;

  if (ref($params{columns}) eq 'ARRAY') {
    @columns = map {
      if (ref($_) eq 'ARRAY') {
        { title => $_->[0], data => $_->[1], link => $_->[2] }
      } else {
        $_;
      }
    } @{ delete $params{columns} };

  } else {
    croak "Wrong type for 'columns' argument: not an array reference";
  }

  my %with_columns = map { ($_ => 1) } @{ _arrayify($params{with_columns}) };
  if ($with_columns{record_link_direction}) {
    push @columns, {
      title => $::locale->text('Link direction'),
      data  => sub {
          $_[0]->{_record_link_to_myself}
        ? $::locale->text('Row is the record itself')
        : $_[0]->{_record_link_depth} > 1
        ? $::locale->text('Row was linked to another record')
        : $_[0]->{_record_link_direction} eq 'from'
        ? $::locale->text('Row was source for current record')
        : $::locale->text('Row was created from current record') },
    };
  }
  if ($with_columns{email_journal_action}) {
    push @columns, {
      title => $::locale->text('Action'),
      data  => sub {
        my $id = $_[0]->id;
        my $record_type = $_[0]->record_type;
        if ($record_type eq 'ap_transaction' && ref $_[0] eq 'SL::DB::RecordTemplate') {
          return is_escaped(
            button_tag(
              "kivi.EmailJournal.ap_transaction_template_with_zugferd_import(
              '$id', '$record_type');",
              $::locale->text('Select (with Factur-X/ZUGFeRD import)'),
            )
          );
        } else {
          return is_escaped(button_tag(
              "kivi.EmailJournal.apply_action_with_attachment(
              '$id', '$record_type');",
              $::locale->text('Select'),
            ));
        }
      },
    };
  }

  my %column_meta   = map { $_->name => $_ } @{ $list->[0]->meta->columns       };
  my %relationships = map { $_->name => $_ } @{ $list->[0]->meta->relationships };

  my $call = sub {
    my ($obj, $method, @args) = @_;
    $obj->$method(@args);
  };

  my @data;
  foreach my $obj (@{ $list }) {
    my @row;

    foreach my $spec (@columns) {
      my %cell;

      my $method       =  $spec->{column} || $spec->{data};
      my $meta         =  $column_meta{ $spec->{data} };
      my $type         =  ref $meta;
      my $relationship =  $relationships{ $spec->{data} };
      my $rel_type     =  !$relationship ? '' : $relationship->class;
      $rel_type        =~ s/^SL::DB:://;
      $rel_type        =  SL::Util::snakify($rel_type);

      if (ref($spec->{data}) eq 'CODE') {
        $cell{value} = $spec->{data}->($obj);

      } else {
        $cell{value} = ref $obj->$method && $obj->$method->isa('SL::DB::Object') && $obj->$method->presenter->can($rel_type) ? $obj->$method->presenter->$rel_type(display => 'table-cell')
                     : $type eq 'Rose::DB::Object::Metadata::Column::Date'                      ? $call->($obj, $method . '_as_date')
                     : $type =~ m/^Rose::DB::Object::Metadata::Column::(?:Float|Numeric|Real)$/ ? $::form->format_amount(\%::myconfig, $call->($obj, $method), 2)
                     : $type eq 'Rose::DB::Object::Metadata::Column::Boolean'                   ? $call->($obj, $method . '_as_bool_yn')
                     : $type =~ m/^Rose::DB::Object::Metadata::Column::(?:Integer|Serial)$/     ? $spec->{data} * 1
                     :                                                                            $call->($obj, $method);
      }

      $cell{alignment} = 'right' if $type =~ m/int|serial|float|real|numeric/;

      push @row, \%cell;
    }

    push @data, { columns => \@row, record_link => $obj->{_record_link} };
  }

  my @header =
    map +{ value     => $columns[$_]->{title},
           alignment => $data[0]->{columns}->[$_]->{alignment},
         }, (0..scalar(@columns) - 1);

  return SL::Presenter->get->render(
    'presenter/record/record_list',
    %params,
    TABLE_HEADER => \@header,
    TABLE_ROWS   => \@data,
  );
}

sub list { goto &record_list }

#
# private methods
#

sub _group_records {
  my ($list) = @_;
  my %matchers = (
    requirement_spec            => sub { (ref($_[0]) eq 'SL::DB::RequirementSpec')                                         },
    shop_order                  => sub { (ref($_[0]) eq 'SL::DB::ShopOrder')       &&  $_[0]->id                           },
    sales_quotation             => sub { (ref($_[0]) eq 'SL::DB::Order')           &&  $_[0]->is_type('sales_quotation')   },
    sales_order_intake          => sub { (ref($_[0]) eq 'SL::DB::Order')           &&  $_[0]->is_type('sales_order_intake') },
    sales_order                 => sub { (ref($_[0]) eq 'SL::DB::Order')           &&  $_[0]->is_type('sales_order')       },
    sales_delivery_order        => sub { (ref($_[0]) eq 'SL::DB::DeliveryOrder')   &&  $_[0]->is_type('sales_delivery_order') },
    rma_delivery_order          => sub { (ref($_[0]) eq 'SL::DB::DeliveryOrder')   &&  $_[0]->is_type('rma_delivery_order')   },
    sales_reclamation           => sub { (ref($_[0]) eq 'SL::DB::Reclamation')     &&  $_[0]->is_type('sales_reclamation') },
    sales_invoice               => sub { (ref($_[0]) eq 'SL::DB::Invoice')         &&  $_[0]->invoice                      },
    ar_transaction              => sub { (ref($_[0]) eq 'SL::DB::Invoice')         && !$_[0]->invoice                      },
    request_quotation           => sub { (ref($_[0]) eq 'SL::DB::Order')           &&  $_[0]->is_type('request_quotation') },
    purchase_quotation_intake   => sub { (ref($_[0]) eq 'SL::DB::Order')           &&  $_[0]->is_type('purchase_quotation_intake') },
    purchase_order              => sub { (ref($_[0]) eq 'SL::DB::Order')           &&  $_[0]->is_type('purchase_order')    },
    purchase_order_confirmation => sub { (ref($_[0]) eq 'SL::DB::Order')           &&  $_[0]->is_type('purchase_order_confirmation')   },
    purchase_delivery_order     => sub { (ref($_[0]) eq 'SL::DB::DeliveryOrder')   &&  $_[0]->is_type('purchase_delivery_order') },
    supplier_delivery_order     => sub { (ref($_[0]) eq 'SL::DB::DeliveryOrder')   &&  $_[0]->is_type('supplier_delivery_order') },
    purchase_reclamation        => sub { (ref($_[0]) eq 'SL::DB::Reclamation')     &&  $_[0]->is_type('purchase_reclamation')},
    purchase_invoice            => sub { (ref($_[0]) eq 'SL::DB::PurchaseInvoice') &&  $_[0]->invoice                      },
    ap_transaction              => sub { (ref($_[0]) eq 'SL::DB::PurchaseInvoice') && !$_[0]->invoice                      },
    sepa_collection             => sub { (ref($_[0]) eq 'SL::DB::SepaExportItem')  &&  $_[0]->ar_id                        },
    sepa_transfer               => sub { (ref($_[0]) eq 'SL::DB::SepaExportItem')  &&  $_[0]->ap_id                        },
    gl_transaction              => sub { (ref($_[0]) eq 'SL::DB::GLTransaction')                                           },
    bank_transaction            => sub { (ref($_[0]) eq 'SL::DB::BankTransaction') &&  $_[0]->id                           },
    letter                      => sub { (ref($_[0]) eq 'SL::DB::Letter')          &&  $_[0]->id                           },
    email_journal               => sub { (ref($_[0]) eq 'SL::DB::EmailJournal')    &&  $_[0]->id                           },
    dunning                     => sub { (ref($_[0]) eq 'SL::DB::Dunning')                                                 },
    gl_transaction_template     => sub { (ref($_[0]) eq 'SL::DB::RecordTemplate')  &&  $_[0]->template_type eq 'gl_transaction' },
    ar_transaction_template     => sub { (ref($_[0]) eq 'SL::DB::RecordTemplate')  &&  $_[0]->template_type eq 'ar_transaction' },
    ap_transaction_template     => sub { (ref($_[0]) eq 'SL::DB::RecordTemplate')  &&  $_[0]->template_type eq 'ap_transaction' },
  );

  my %groups;

  foreach my $record (@{ $list || [] }) {
    my $type         = (first { $matchers{$_}->($record) } keys %matchers) || 'other';
    $groups{$type} ||= [];
    push @{ $groups{$type} }, $record;
  }

  return %groups;
}

sub _sort_grouped_lists {
  my (%groups) = @_;

  foreach my $group (keys %groups) {
    next unless @{ $groups{$group} };
    if ($groups{$group}->[0]->can('compare_to')) {
      $groups{$group} = [ sort { $a->compare_to($b)    } @{ $groups{$group} } ];
    } else {
      $groups{$group} = [ sort { $a->date <=> $b->date } @{ $groups{$group} } ];
    }
  }

  return %groups;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Record - Presenter module for lists of
sales/purchase/general ledger record Rose::DB objects

=head1 SYNOPSIS

  # Retrieve a number of documents from somewhere, e.g.
  my $order   = SL::DB::Manager::Order->get_first(where => [ SL::DB::Manager::Order->type_filter('sales_order') ]);
  my $records = $order->linked_records(destination => 'to');

  # Give HTML representation:
  my $html = SL::Presenter->get->grouped_record_list($records);
  # simple html version:
  my $html = SL::Presenter->get->simple_grouped_record_list($records);

=head1 OVERVIEW

TODO

=head1 FUNCTIONS

=over 4

=item C<record>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of a single ar, ap or gl object.

Example:
  # fetch the record from a random acc_trans object and print its link (could be ar, ap or gl)
  my $record = SL::DB::Manager::AccTransaction->get_first()->record;
  my $html   = SL::Presenter->get->record($record, display => 'inline');

=item C<empty_record_list>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of an empty list of records. Is usually
only called by L<grouped_record_list> if its list is empty.

=item C<simple_grouped_record_list $list, %params>

Generates a simple list of records. The order of the records is the
same as in L<grouped_record_list>.

=item C<grouped_record_list $list, %params>

Given a number of Rose::DB objects in the array reference C<$list>
this function first groups them by type. Then it calls L<record_list>
with each non-empty type-specific sub-list and the appropriate
parameters for outputting a list of those records.

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of all the lists.

The order in which the records are grouped is:

=over 2

=item * sales quotations

=item * sales orders

=item * sales delivery orders

=item * rma delivery orders

=item * sales reclamation

=item * sales invoices

=item * AR transactions

=item * requests for quotations

=item * purchase orders

=item * purchase delivery orders

=item * supplier delivery orders

=item * purchase reclamation

=item * purchase invoices

=item * AP transactions

=item * GL transactions

=item * SEPA collections

=item * SEPA transfers

=back

Objects of unknown types are skipped.

Parameters are passed to C<record_list> include C<with_objects> and
C<edit_record_links>.

=item C<record_list $list, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of a list of records. This list
consists of a heading and a tabular representation of the list.

The parameters include:

=over 2

=item C<title>

Mandatory. The title to use in the heading. Must already be
translated.

=item C<columns>

Mandatory. An array reference of column specs to output. Each column
spec can be either an array reference or a hash reference.

If a column spec is an array reference then the first element is the
column's name shown in the table header. It must already be translated.

The second element can be either a string or a code reference. A
string is taken as the name of a function to call on the Rose::DB
object for the current row. Its return value is formatted depending on
the column's type (e.g. dates are output as the user expects them,
floating point numbers are rounded to two decimal places and
right-aligned etc). If it is a code reference then that code is called
with the object as the first argument. Its return value should be an
instance of L<SL::Presenter::EscapedText> and contain the rendered
representation of the content to output.

The third element, if present, can be a link to which the column will
be linked.

If the column spec is a hash reference then the same arguments are
expected. The corresponding hash keys are C<title>, C<data> and
C<link>.

=item C<with_columns>

Can be set by the caller to indicate additional columns to
be listed. Currently supported:

=over 2

=item C<record_link_destination>

The record link destination. Requires that the records to be listed have
been retrieved via the L<SL::DB::Helper::LinkedRecords> helper.

=back

=item C<edit_record_links>

If trueish additional controls will be rendered that allow the user to
remove and add record links. Requires that the records to be listed have
been retrieved via the L<SL::DB::Helper::LinkedRecords> helper.

=back

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
