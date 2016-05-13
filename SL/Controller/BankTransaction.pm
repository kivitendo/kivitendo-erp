package SL::Controller::BankTransaction;

# idee- möglichkeit bankdaten zu übernehmen in stammdaten
# erst Kontenabgleich, um alle gl-Einträge wegzuhaben
use strict;

use parent qw(SL::Controller::Base);

use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ReportGenerator;
use SL::ReportGenerator;

use SL::DB::BankTransaction;
use SL::Helper::Flash;
use SL::Locale::String;
use SL::SEPA;
use SL::DB::Invoice;
use SL::DB::PurchaseInvoice;
use SL::DB::RecordLink;
use SL::JSON;
use SL::DB::Chart;
use SL::DB::AccTransaction;
use SL::DB::Tax;
use SL::DB::Draft;
use SL::DB::BankAccount;
use SL::DBUtils qw(like);
use SL::Presenter;
use List::Util qw(max);

use Rose::Object::MakeMethods::Generic
(
 'scalar --get_set_init' => [ qw(models) ],
);

__PACKAGE__->run_before('check_auth');


#
# actions
#

sub action_search {
  my ($self) = @_;

  my $bank_accounts = SL::DB::Manager::BankAccount->get_all_sorted( query => [ obsolete => 0 ] );

  $self->render('bank_transactions/search',
                 BANK_ACCOUNTS => $bank_accounts);
}

sub action_list_all {
  my ($self) = @_;

  $self->make_filter_summary;
  $self->prepare_report;

  $self->report_generator_list_objects(report => $self->{report}, objects => $self->models->get);
}

sub action_list {
  my ($self) = @_;

  if (!$::form->{filter}{bank_account}) {
    flash('error', t8('No bank account chosen!'));
    $self->action_search;
    return;
  }

  my $sort_by = $::form->{sort_by} || 'transdate';
  $sort_by = 'transdate' if $sort_by eq 'proposal';
  $sort_by .= $::form->{sort_dir} ? ' DESC' : ' ASC';

  my $fromdate = $::locale->parse_date_to_object($::form->{filter}->{fromdate});
  my $todate   = $::locale->parse_date_to_object($::form->{filter}->{todate});
  $todate->add( days => 1 ) if $todate;

  my @where = ();
  push @where, (transdate => { ge => $fromdate }) if ($fromdate);
  push @where, (transdate => { lt => $todate })   if ($todate);
  my $bank_account = SL::DB::Manager::BankAccount->find_by( id => $::form->{filter}{bank_account} );
  # bank_transactions no younger than starting date,
  # including starting date (same search behaviour as fromdate)
  # but OPEN invoices to be matched may be from before
  if ( $bank_account->reconciliation_starting_date ) {
    push @where, (transdate => { ge => $bank_account->reconciliation_starting_date });
  };

  my $bank_transactions = SL::DB::Manager::BankTransaction->get_all(where => [ amount => {ne => \'invoice_amount'},
                                                                               local_bank_account_id => $::form->{filter}{bank_account},
                                                                               @where ],
                                                                    with_objects => [ 'local_bank_account', 'currency' ],
                                                                    sort_by => $sort_by, limit => 10000);

  my $all_open_ar_invoices = SL::DB::Manager::Invoice->get_all(where => [amount => { gt => \'paid' }], with_objects => 'customer');
  my $all_open_ap_invoices = SL::DB::Manager::PurchaseInvoice->get_all(where => [amount => { gt => \'paid' }], with_objects => 'vendor');

  my @all_open_invoices;
  # filter out invoices with less than 1 cent outstanding
  push @all_open_invoices, grep { abs($_->amount - $_->paid) >= 0.01 } @{ $all_open_ar_invoices };
  push @all_open_invoices, grep { abs($_->amount - $_->paid) >= 0.01 } @{ $all_open_ap_invoices };

  # try to match each bank_transaction with each of the possible open invoices
  # by awarding points

  foreach my $bt (@{ $bank_transactions }) {
    next unless $bt->{remote_name};  # bank has no name, usually fees, use create invoice to assign

    $bt->{remote_name} .= $bt->{remote_name_1} if $bt->{remote_name_1};

    # try to match the current $bt to each of the open_invoices, saving the
    # results of get_agreement_with_invoice in $open_invoice->{agreement} and
    # $open_invoice->{rule_matches}.

    # The values are overwritten each time a new bt is checked, so at the end
    # of each bt the likely results are filtered and those values are stored in
    # the arrays $bt->{proposals} and $bt->{rule_matches}, and the agreement
    # score is stored in $bt->{agreement}

    foreach my $open_invoice (@all_open_invoices){
      ($open_invoice->{agreement}, $open_invoice->{rule_matches}) = $bt->get_agreement_with_invoice($open_invoice);
    };

    $bt->{proposals} = [];

    my $agreement = 15;
    my $min_agreement = 3; # suggestions must have at least this score

    my $max_agreement = max map { $_->{agreement} } @all_open_invoices;

    # add open_invoices with highest agreement into array $bt->{proposals}
    if ( $max_agreement >= $min_agreement ) {
      $bt->{proposals} = [ grep { $_->{agreement} == $max_agreement } @all_open_invoices ];
      $bt->{agreement} = $max_agreement; #scalar @{ $bt->{proposals} } ? $agreement + 1 : '';

      # store the rule_matches in a separate array, so they can be displayed in template
      foreach ( @{ $bt->{proposals} } ) {
        push(@{$bt->{rule_matches}}, $_->{rule_matches});
      };
    };
  }  # finished one bt
  # finished all bt

  # separate filter for proposals (second tab, agreement >= 5 and exactly one match)
  # to qualify as a proposal there has to be
  # * agreement >= 5  TODO: make threshold configurable in configuration
  # * there must be only one exact match
  # * depending on whether sales or purchase the amount has to have the correct sign (so Gutschriften don't work?)
  my $proposal_threshold = 5;
  my @proposals = grep { $_->{agreement} >= $proposal_threshold
                         and 1 == scalar @{ $_->{proposals} }
                         and (@{ $_->{proposals} }[0]->is_sales ? abs(@{ $_->{proposals} }[0]->amount - $_->amount) < 0.01  : abs(@{ $_->{proposals} }[0]->amount + $_->amount) < 0.01) } @{ $bank_transactions };

  # sort bank transaction proposals by quality (score) of proposal
  $bank_transactions = [ sort { $a->{agreement} <=> $b->{agreement} } @{ $bank_transactions } ] if $::form->{sort_by} eq 'proposal' and $::form->{sort_dir} == 1;
  $bank_transactions = [ sort { $b->{agreement} <=> $a->{agreement} } @{ $bank_transactions } ] if $::form->{sort_by} eq 'proposal' and $::form->{sort_dir} == 0;


  $self->render('bank_transactions/list',
                title             => t8('Bank transactions MT940'),
                BANK_TRANSACTIONS => $bank_transactions,
                PROPOSALS         => \@proposals,
                bank_account      => $bank_account );
}

sub action_assign_invoice {
  my ($self) = @_;

  $self->{transaction} = SL::DB::Manager::BankTransaction->find_by(id => $::form->{bt_id});

  $self->render('bank_transactions/assign_invoice', { layout  => 0 },
                title      => t8('Assign invoice'),);
}

sub action_create_invoice {
  my ($self) = @_;
  my %myconfig = %main::myconfig;

  $self->{transaction} = SL::DB::Manager::BankTransaction->find_by(id => $::form->{bt_id});
  my $vendor_of_transaction = SL::DB::Manager::Vendor->find_by(account_number => $self->{transaction}->{remote_account_number});

  my $drafts = SL::DB::Manager::Draft->get_all(where => [ module => 'ap'] , with_objects => 'employee');

  my @filtered_drafts;

  foreach my $draft ( @{ $drafts } ) {
    my $draft_as_object = YAML::Load($draft->form);
    my $vendor = SL::DB::Manager::Vendor->find_by(id => $draft_as_object->{vendor_id});
    $draft->{vendor} = $vendor->name;
    $draft->{vendor_id} = $vendor->id;
    push @filtered_drafts, $draft;
  }

  #Filter drafts
  @filtered_drafts = grep { $_->{vendor_id} == $vendor_of_transaction->id } @filtered_drafts if $vendor_of_transaction;

  my $all_vendors = SL::DB::Manager::Vendor->get_all();

  $self->render('bank_transactions/create_invoice', { layout  => 0 },
      title      => t8('Create invoice'),
      DRAFTS     => \@filtered_drafts,
      vendor_id  => $vendor_of_transaction ? $vendor_of_transaction->id : undef,
      vendor_name => $vendor_of_transaction ? $vendor_of_transaction->name : undef,
      ALL_VENDORS => $all_vendors,
      limit      => $myconfig{vclimit},
      callback   => $self->url_for(action                => 'list',
                                   'filter.bank_account' => $::form->{filter}->{bank_account},
                                   'filter.todate'       => $::form->{filter}->{todate},
                                   'filter.fromdate'     => $::form->{filter}->{fromdate}),
      );
}

sub action_ajax_payment_suggestion {
  my ($self) = @_;

  # based on a BankTransaction ID and a Invoice or PurchaseInvoice ID passed via $::form,
  # create an HTML blob to be used by the js function add_invoices in templates/webpages/bank_transactions/list.html
  # and return encoded as JSON

  my $bt = SL::DB::Manager::BankTransaction->find_by( id => $::form->{bt_id} );
  my $invoice = SL::DB::Manager::Invoice->find_by( id => $::form->{prop_id} );
  $invoice = SL::DB::Manager::PurchaseInvoice->find_by( id => $::form->{prop_id} ) unless $invoice;

  die unless $bt and $invoice;

  my @select_options = $invoice->get_payment_select_options_for_bank_transaction($::form->{bt_id});

  my $html;
  $html .= SL::Presenter->input_tag('invoice_ids.' . $::form->{bt_id} . '[]', $::form->{prop_id} , type => 'hidden');
  $html .= SL::Presenter->escape( $invoice->invnumber );
  $html .= SL::Presenter->select_tag('invoice_skontos.' . $::form->{bt_id} . '[]', \@select_options,
                                              value_key => 'payment_type',
                                              title_key => 'display' ) if @select_options;
  $html .= '<a href=# onclick="delete_invoice(' . $::form->{bt_id} . ',' . $::form->{prop_id} . ');">x</a>';
  $html = SL::Presenter->html_tag('div', $html, id => $::form->{bt_id} . '.' . $::form->{prop_id});

  $self->render(\ SL::JSON::to_json( { 'html' => $html } ), { layout => 0, type => 'json', process => 0 });
};

sub action_filter_drafts {
  my ($self) = @_;

  $self->{transaction} = SL::DB::Manager::BankTransaction->find_by(id => $::form->{bt_id});
  my $vendor_of_transaction = SL::DB::Manager::Vendor->find_by(account_number => $self->{transaction}->{remote_account_number});

  my $drafts = SL::DB::Manager::Draft->get_all(with_objects => 'employee');

  my @filtered_drafts;

  foreach my $draft ( @{ $drafts } ) {
    my $draft_as_object = YAML::Load($draft->form);
    my $vendor = SL::DB::Manager::Vendor->find_by(id => $draft_as_object->{vendor_id});
    $draft->{vendor} = $vendor->name;
    $draft->{vendor_id} = $vendor->id;
    push @filtered_drafts, $draft;
  }

  my $vendor_name = $::form->{vendor};
  my $vendor_id = $::form->{vendor_id};

  #Filter drafts
  @filtered_drafts = grep { $_->{vendor_id} == $vendor_id } @filtered_drafts if $vendor_id;
  @filtered_drafts = grep { $_->{vendor} =~ /$vendor_name/i } @filtered_drafts if $vendor_name;

  my $output  = $self->render(
      'bank_transactions/filter_drafts',
      { output      => 0 },
      DRAFTS => \@filtered_drafts,
      );

  my %result = ( count => 0, html => $output );

  $self->render(\to_json(\%result), { type => 'json', process => 0 });
}

sub action_ajax_add_list {
  my ($self) = @_;

  my @where_sale     = (amount => { ne => \'paid' });
  my @where_purchase = (amount => { ne => \'paid' });

  if ($::form->{invnumber}) {
    push @where_sale,     (invnumber => { ilike => like($::form->{invnumber})});
    push @where_purchase, (invnumber => { ilike => like($::form->{invnumber})});
  }

  if ($::form->{amount}) {
    push @where_sale,     (amount => $::form->parse_amount(\%::myconfig, $::form->{amount}));
    push @where_purchase, (amount => $::form->parse_amount(\%::myconfig, $::form->{amount}));
  }

  if ($::form->{vcnumber}) {
    push @where_sale,     ('customer.customernumber' => { ilike => like($::form->{vcnumber})});
    push @where_purchase, ('vendor.vendornumber'     => { ilike => like($::form->{vcnumber})});
  }

  if ($::form->{vcname}) {
    push @where_sale,     ('customer.name' => { ilike => like($::form->{vcname})});
    push @where_purchase, ('vendor.name'   => { ilike => like($::form->{vcname})});
  }

  if ($::form->{transdatefrom}) {
    my $fromdate = $::locale->parse_date_to_object($::form->{transdatefrom});
    if ( ref($fromdate) eq 'DateTime' ) {
      push @where_sale,     ('transdate' => { ge => $fromdate});
      push @where_purchase, ('transdate' => { ge => $fromdate});
    };
  }

  if ($::form->{transdateto}) {
    my $todate = $::locale->parse_date_to_object($::form->{transdateto});
    if ( ref($todate) eq 'DateTime' ) {
      $todate->add(days => 1);
      push @where_sale,     ('transdate' => { lt => $todate});
      push @where_purchase, ('transdate' => { lt => $todate});
    };
  }

  my $all_open_ar_invoices = SL::DB::Manager::Invoice->get_all(where => \@where_sale, with_objects => 'customer');
  my $all_open_ap_invoices = SL::DB::Manager::PurchaseInvoice->get_all(where => \@where_purchase, with_objects => 'vendor');

  my @all_open_invoices = @{ $all_open_ar_invoices };
  # add ap invoices, filtering out subcent open amounts
  push @all_open_invoices, grep { abs($_->amount - $_->paid) >= 0.01 } @{ $all_open_ap_invoices };

  @all_open_invoices = sort { $a->id <=> $b->id } @all_open_invoices;

  my $output  = $self->render(
      'bank_transactions/add_list',
      { output      => 0 },
      INVOICES => \@all_open_invoices,
      );

  my %result = ( count => 0, html => $output );

  $self->render(\to_json(\%result), { type => 'json', process => 0 });
}

sub action_ajax_accept_invoices {
  my ($self) = @_;

  my @selected_invoices;
  foreach my $invoice_id (@{ $::form->{invoice_id} || [] }) {
    my $invoice_object = SL::DB::Manager::Invoice->find_by(id => $invoice_id);
    $invoice_object ||= SL::DB::Manager::PurchaseInvoice->find_by(id => $invoice_id);

    push @selected_invoices, $invoice_object;
  }

  $self->render('bank_transactions/invoices', { layout => 0 },
                INVOICES => \@selected_invoices,
                bt_id    => $::form->{bt_id} );
}

sub action_save_invoices {
  my ($self) = @_;

  my $invoice_hash = delete $::form->{invoice_ids}; # each key (the bt line with a bt_id) contains an array of invoice_ids
  my $skonto_hash  = delete $::form->{invoice_skontos} || {}; # array containing the payment type, could be empty

  # a bank_transaction may be assigned to several invoices, i.e. a customer
  # might pay several open invoices with one transaction

  while ( my ($bt_id, $invoice_ids) = each(%$invoice_hash) ) {
    my $bank_transaction = SL::DB::Manager::BankTransaction->find_by(id => $bt_id);
    my $sign = $bank_transaction->amount < 0 ? -1 : 1;
    my $amount_of_transaction = $sign * $bank_transaction->amount;

    my @invoices;
    foreach my $invoice_id (@{ $invoice_ids }) {
      push @invoices, (SL::DB::Manager::Invoice->find_by(id => $invoice_id) || SL::DB::Manager::PurchaseInvoice->find_by(id => $invoice_id));
    }
    @invoices = sort { return 1 if ($a->is_sales and $a->amount > 0);
                          return 1 if (!$a->is_sales and $a->amount < 0);
                          return -1; } @invoices                if $bank_transaction->amount > 0;
    @invoices = sort { return -1 if ($a->is_sales and $a->amount > 0);
                       return -1 if (!$a->is_sales and $a->amount < 0);
                       return 1; } @invoices                    if $bank_transaction->amount < 0;

    foreach my $invoice (@invoices) {

      # Check if bank_transaction already has a link to the invoice, may only be linked once per invoice
      # This might be caused by the user reloading a page and resending the form
      die t8("Bank transaction with id #1 has already been linked to #2.", $bank_transaction->id, $invoice->displayable_name)
        if _existing_record_link($bank_transaction, $invoice);

      my $payment_type;
      if ( defined $skonto_hash->{"$bt_id"} ) {
        $payment_type = shift(@{ $skonto_hash->{"$bt_id"} });
      } else {
        $payment_type = 'without_skonto';
      };
      if ($amount_of_transaction == 0) {
        flash('warning',  $::locale->text('There are invoices which could not be paid by bank transaction #1 (Account number: #2, bank code: #3)!',
                                            $bank_transaction->purpose,
                                            $bank_transaction->remote_account_number,
                                            $bank_transaction->remote_bank_code));
        last;
      }
      # pay invoice or go to the next bank transaction if the amount is not sufficiently high
      if ($invoice->amount_open <= $amount_of_transaction) {
        $invoice->pay_invoice(chart_id     => $bank_transaction->local_bank_account->chart_id,
                              trans_id     => $invoice->id,
                              amount       => $invoice->amount_open,
                              payment_type => $payment_type,
                              transdate    => $bank_transaction->transdate->to_kivitendo);
        if ($invoice->is_sales) {
          $amount_of_transaction -= $sign * $invoice->amount_open;
          $bank_transaction->invoice_amount($bank_transaction->invoice_amount + $invoice->amount_open);
        } else {
          $amount_of_transaction += $sign * $invoice->amount_open if (!$invoice->is_sales);
          $bank_transaction->invoice_amount($bank_transaction->invoice_amount - $invoice->amount_open);
        }
      } else {
        $invoice->pay_invoice(chart_id     => $bank_transaction->local_bank_account->chart_id,
                              trans_id     => $invoice->id,
                              amount       => $amount_of_transaction,
                              payment_type => $payment_type,
                              transdate    => $bank_transaction->transdate->to_kivitendo);
        $bank_transaction->invoice_amount($bank_transaction->amount) if $invoice->is_sales;
        $bank_transaction->invoice_amount($bank_transaction->amount) if !$invoice->is_sales;
        $amount_of_transaction = 0;
      }

      # Record a record link from the bank transaction to the invoice
      my @props = (
          from_table => 'bank_transactions',
          from_id    => $bt_id,
          to_table   => $invoice->is_sales ? 'ar' : 'ap',
          to_id      => $invoice->id,
          );

      SL::DB::RecordLink->new(@props)->save;
    }
    $bank_transaction->save;
  }

  $self->action_list();
}

sub action_save_proposals {
  my ($self) = @_;

  foreach my $bt_id (@{ $::form->{proposal_ids} }) {
    my $bt = SL::DB::Manager::BankTransaction->find_by(id => $bt_id);

    my $arap = SL::DB::Manager::Invoice->find_by(id => $::form->{"proposed_invoice_$bt_id"});
    $arap    = SL::DB::Manager::PurchaseInvoice->find_by(id => $::form->{"proposed_invoice_$bt_id"}) if not defined $arap;

    # check for existing record_link for that $bt and $arap
    # do this before any changes to $bt are made
    die t8("Bank transaction with id #1 has already been linked to #2.", $bt->id, $arap->displayable_name)
      if _existing_record_link($bt, $arap);

    #mark bt as booked
    $bt->invoice_amount($bt->amount);
    $bt->save;

    #pay invoice
    $arap->pay_invoice(chart_id  => $bt->local_bank_account->chart_id,
                       trans_id  => $arap->id,
                       amount    => $arap->amount,
                       transdate => $bt->transdate->to_kivitendo);
    $arap->save;

    #create record link
    my @props = (
        from_table => 'bank_transactions',
        from_id    => $bt_id,
        to_table   => $arap->is_sales ? 'ar' : 'ap',
        to_id      => $arap->id,
        );

    SL::DB::RecordLink->new(@props)->save;
  }

  flash('ok', t8('#1 proposal(s) saved.', scalar @{ $::form->{proposal_ids} }));

  $self->action_list();
}

#
# filters
#

sub check_auth {
  $::auth->assert('bank_transaction');
}

#
# helpers
#

sub make_filter_summary {
  my ($self) = @_;

  my $filter = $::form->{filter} || {};
  my @filter_strings;

  my @filters = (
    [ $filter->{"transdate:date::ge"},  $::locale->text('Transdate')  . " " . $::locale->text('From Date') ],
    [ $filter->{"transdate:date::le"},  $::locale->text('Transdate')  . " " . $::locale->text('To Date')   ],
    [ $filter->{"valutadate:date::ge"}, $::locale->text('Valutadate') . " " . $::locale->text('From Date') ],
    [ $filter->{"valutadate:date::le"}, $::locale->text('Valutadate') . " " . $::locale->text('To Date')   ],
    [ $filter->{"amount:number"},       $::locale->text('Amount')                                          ],
    [ $filter->{"bank_account_id:integer"}, $::locale->text('Local bank account')                          ],
  );

  for (@filters) {
    push @filter_strings, "$_->[1]: $_->[0]" if $_->[0];
  }

  $self->{filter_summary} = join ', ', @filter_strings;
}

sub prepare_report {
  my ($self)      = @_;

  my $callback    = $self->models->get_callback;

  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns     = qw(local_bank_name transdate valudate remote_name remote_account_number remote_bank_code amount invoice_amount invoices currency purpose local_account_number local_bank_code id);
  my @sortable    = qw(local_bank_name transdate valudate remote_name remote_account_number remote_bank_code amount                                  purpose local_account_number local_bank_code);

  my %column_defs = (
    transdate             => { sub => sub { $_[0]->transdate_as_date } },
    valutadate            => { sub => sub { $_[0]->valutadate_as_date } },
    remote_name           => { },
    remote_account_number => { },
    remote_bank_code      => { },
    amount                => { sub => sub { $_[0]->amount_as_number },
                               align => 'right' },
    invoice_amount        => { sub => sub { $_[0]->invoice_amount_as_number },
                               align => 'right' },
    invoices              => { sub => sub { $_[0]->linked_invoices } },
    currency              => { sub => sub { $_[0]->currency->name } },
    purpose               => { },
    local_account_number  => { sub => sub { $_[0]->local_bank_account->account_number } },
    local_bank_code       => { sub => sub { $_[0]->local_bank_account->bank_code } },
    local_bank_name       => { sub => sub { $_[0]->local_bank_account->name } },
    id                    => {},
  );

  map { $column_defs{$_}->{text} ||= $::locale->text( $self->models->get_sort_spec->{$_}->{title} ) } keys %column_defs;

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'BankTransaction',
    output_format         => 'HTML',
    top_info_text         => $::locale->text('Bank transactions'),
    title                 => $::locale->text('Bank transactions'),
    allow_pdf_export      => 1,
    allow_csv_export      => 1,
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list_all filter));
  $report->set_options_from_form;
  $self->models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->models->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);

  my $bank_accounts = SL::DB::Manager::BankAccount->get_all_sorted();

  $report->set_options(
    raw_top_info_text     => $self->render('bank_transactions/report_top',    { output => 0 }, BANK_ACCOUNTS => $bank_accounts),
    raw_bottom_info_text  => $self->render('bank_transactions/report_bottom', { output => 0 }),
  );
}

sub _existing_record_link {
  my ($bt, $invoice) = @_;

  # check whether a record link from banktransaction $bt already exists to
  # invoice $invoice, returns 1 if that is the case

  die unless $bt->isa("SL::DB::BankTransaction") && ( $invoice->isa("SL::DB::Invoice") || $invoice->isa("SL::DB::PurchaseInvoice") );

  my $linked_record_to_table = $invoice->is_sales ? 'Invoice' : 'PurchaseInvoice';
  my $linked_records = $bt->linked_records( direction => 'to', to => $linked_record_to_table, query => [ id => $invoice->id ]  );

  return @$linked_records ? 1 : 0;
};


sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    sorted => {
      _default => {
        by    => 'transdate',
        dir   => 0,   # 1 = ASC, 0 = DESC : default sort is newest at top
      },
      transdate             => t8('Transdate'),
      remote_name           => t8('Remote name'),
      amount                => t8('Amount'),
      invoice_amount        => t8('Assigned'),
      invoices              => t8('Linked invoices'),
      valutadate            => t8('Valutadate'),
      remote_account_number => t8('Remote account number'),
      remote_bank_code      => t8('Remote bank code'),
      currency              => t8('Currency'),
      purpose               => t8('Purpose'),
      local_account_number  => t8('Local account number'),
      local_bank_code       => t8('Local bank code'),
      local_bank_name       => t8('Bank account'),
    },
    with_objects => [ 'local_bank_account', 'currency' ],
  );
}

1;
