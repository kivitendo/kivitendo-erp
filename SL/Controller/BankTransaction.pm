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
use SL::DB::ReconciliationLink;
use SL::JSON;
use SL::DB::Chart;
use SL::DB::AccTransaction;
use SL::DB::BankTransactionAccTrans;
use SL::DB::Tax;
use SL::DB::BankAccount;
use SL::DB::GLTransaction;
use SL::DB::RecordTemplate;
use SL::DB::SepaExportItem;
use SL::DBUtils qw(like do_query);

use SL::Presenter::Tag qw(checkbox_tag html_tag);
use Carp;
use List::UtilsBy qw(partition_by);
use List::MoreUtils qw(any);
use List::Util qw(max);

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(callback transaction) ],
  'scalar --get_set_init' => [ qw(models problems) ],
);

__PACKAGE__->run_before('check_auth');


#
# actions
#

sub action_search {
  my ($self) = @_;

  my $bank_accounts = SL::DB::Manager::BankAccount->get_all_sorted( query => [ obsolete => 0 ] );

  $self->setup_search_action_bar;
  $self->render('bank_transactions/search',
                 BANK_ACCOUNTS => $bank_accounts);
}

sub action_list_all {
  my ($self) = @_;

  $self->make_filter_summary;
  $self->prepare_report;

  $self->setup_list_all_action_bar;
  $self->report_generator_list_objects(report => $self->{report}, objects => $self->models->get);
}

sub gather_bank_transactions_and_proposals {
  my ($self, %params) = @_;

  my $sort_by = $params{sort_by} || 'transdate';
  $sort_by = 'transdate' if $sort_by eq 'proposal';
  $sort_by .= $params{sort_dir} ? ' DESC' : ' ASC';

  my @where = ();
  push @where, (transdate => { ge => $params{fromdate} }) if $params{fromdate};
  push @where, (transdate => { lt => $params{todate} })   if $params{todate};
  # bank_transactions no younger than starting date,
  # including starting date (same search behaviour as fromdate)
  # but OPEN invoices to be matched may be from before
  if ( $params{bank_account}->reconciliation_starting_date ) {
    push @where, (transdate => { ge => $params{bank_account}->reconciliation_starting_date });
  };

  my $bank_transactions = SL::DB::Manager::BankTransaction->get_all(
    with_objects => [ 'local_bank_account', 'currency' ],
    sort_by      => $sort_by,
    limit        => 10000,
    where        => [
      amount                => {ne => \'invoice_amount'},
      local_bank_account_id => $params{bank_account}->id,
      cleared               => 0,
      @where
    ],
  );
  # credit notes have a negative amount, treat differently
  my $all_open_ar_invoices = SL::DB::Manager::Invoice        ->get_all(where => [ or => [ amount => { gt => \'paid' },
                                                                                          and => [ type    => 'credit_note',
                                                                                                   amount  => { lt => \'paid' }
                                                                                                 ],
                                                                                        ],
                                                                                ],
                                                                       with_objects => ['customer','payment_terms']);

  my $all_open_ap_invoices = SL::DB::Manager::PurchaseInvoice->get_all(where => [amount => { ne => \'paid' }], with_objects => ['vendor'  ,'payment_terms']);
  my $all_open_sepa_export_items = SL::DB::Manager::SepaExportItem->get_all(where => [chart_id => $params{bank_account}->chart_id ,
                                                                             'sepa_export.executed' => 0, 'sepa_export.closed' => 0 ], with_objects => ['sepa_export']);

  my @all_open_invoices;
  # filter out invoices with less than 1 cent outstanding
  push @all_open_invoices, map { $_->{is_ar}=1 ; $_ } grep { abs($_->amount - $_->paid) >= 0.01 } @{ $all_open_ar_invoices };
  push @all_open_invoices, map { $_->{is_ar}=0 ; $_ } grep { abs($_->amount - $_->paid) >= 0.01 } @{ $all_open_ap_invoices };

  my %sepa_exports;
  my %sepa_export_items_by_id = partition_by { $_->ar_id || $_->ap_id } @$all_open_sepa_export_items;

  # first collect sepa export items to open invoices
  foreach my $open_invoice (@all_open_invoices){
    $open_invoice->{realamount}  = $::form->format_amount(\%::myconfig,$open_invoice->amount,2);
    $open_invoice->{skonto_type} = 'without_skonto';
    foreach (@{ $sepa_export_items_by_id{ $open_invoice->id } || [] }) {
      my $factor                   = ($_->ar_id == $open_invoice->id ? 1 : -1);
      $open_invoice->{realamount}  = $::form->format_amount(\%::myconfig,$open_invoice->amount*$factor,2);

      $open_invoice->{skonto_type} = $_->payment_type;
      $sepa_exports{$_->sepa_export_id} ||= { count => 0, is_ar => 0, amount => 0, proposed => 0, invoices => [], item => $_ };
      $sepa_exports{$_->sepa_export_id}->{count}++;
      $sepa_exports{$_->sepa_export_id}->{is_ar}++ if  $_->ar_id == $open_invoice->id;
      $sepa_exports{$_->sepa_export_id}->{amount} += $_->amount * $factor;
      push @{ $sepa_exports{$_->sepa_export_id}->{invoices} }, $open_invoice;
    }
  }

  # try to match each bank_transaction with each of the possible open invoices
  # by awarding points
  my @proposals;

  foreach my $bt (@{ $bank_transactions }) {
    ## 5 Stellen hinter dem Komma auf 2 Stellen reduzieren
    $bt->amount($bt->amount*1);
    $bt->invoice_amount($bt->invoice_amount*1);

    $bt->{proposals}    = [];
    $bt->{rule_matches} = [];

    $bt->{remote_name} .= $bt->{remote_name_1} if $bt->{remote_name_1};

    if ( $bt->is_batch_transaction ) {
      my $found=0;
      foreach ( keys  %sepa_exports) {
        if ( abs(($sepa_exports{$_}->{amount} * 1) - ($bt->amount * 1)) < 0.01 ) {
          ## jupp
          @{$bt->{proposals}} = @{$sepa_exports{$_}->{invoices}};
          $bt->{sepa_export_ok} = 1;
          $sepa_exports{$_}->{proposed}=1;
          push(@proposals, $bt);
          $found=1;
          last;
        }
      }
      next if $found;
      # batch transaction has no remotename !!
    } else {
      next unless $bt->{remote_name};  # bank has no name, usually fees, use create invoice to assign
    }

    # try to match the current $bt to each of the open_invoices, saving the
    # results of get_agreement_with_invoice in $open_invoice->{agreement} and
    # $open_invoice->{rule_matches}.

    # The values are overwritten each time a new bt is checked, so at the end
    # of each bt the likely results are filtered and those values are stored in
    # the arrays $bt->{proposals} and $bt->{rule_matches}, and the agreement
    # score is stored in $bt->{agreement}

    foreach my $open_invoice (@all_open_invoices) {
      ($open_invoice->{agreement}, $open_invoice->{rule_matches}) = $bt->get_agreement_with_invoice($open_invoice,
        sepa_export_items => $all_open_sepa_export_items,
      );
      $open_invoice->{realamount} = $::form->format_amount(\%::myconfig,
                                      $open_invoice->amount * ($open_invoice->{is_ar} ? 1 : -1), 2);
    }

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
  my $proposal_threshold = 5;
  my @otherproposals = grep {
       ($_->{agreement} >= $proposal_threshold)
    && (1 == scalar @{ $_->{proposals} })
  } @{ $bank_transactions };

  push @proposals, @otherproposals;

  # sort bank transaction proposals by quality (score) of proposal
  if ($params{sort_by} && $params{sort_by} eq 'proposal') {
    my $dir = $params{sort_dir} ? 1 : -1;
    $bank_transactions = [ sort { ($a->{agreement} <=> $b->{agreement}) * $dir } @{ $bank_transactions } ];
  }

  return ( $bank_transactions , \@proposals );
}

sub action_list {
  my ($self) = @_;

  if (!$::form->{filter}{bank_account}) {
    flash('error', t8('No bank account chosen!'));
    $self->action_search;
    return;
  }

  my $bank_account = SL::DB::BankAccount->load_cached($::form->{filter}->{bank_account});
  my $fromdate     = $::locale->parse_date_to_object($::form->{filter}->{fromdate});
  my $todate       = $::locale->parse_date_to_object($::form->{filter}->{todate});
  $todate->add( days => 1 ) if $todate;

  my ($bank_transactions, $proposals) = $self->gather_bank_transactions_and_proposals(
    bank_account => $bank_account,
    fromdate     => $fromdate,
    todate       => $todate,
    sort_by      => $::form->{sort_by},
    sort_dir     => $::form->{sort_dir},
  );

  $::request->layout->add_javascripts("kivi.BankTransaction.js");
  $self->render('bank_transactions/list',
                title             => t8('Bank transactions MT940'),
                BANK_TRANSACTIONS => $bank_transactions,
                PROPOSALS         => $proposals,
                bank_account      => $bank_account,
                ui_tab            => scalar(@{ $proposals }) > 0 ? 1 : 0,
              );
}

sub action_assign_invoice {
  my ($self) = @_;

  $self->{transaction} = SL::DB::Manager::BankTransaction->find_by(id => $::form->{bt_id});

  $self->render('bank_transactions/assign_invoice',
                { layout => 0 },
                title => t8('Assign invoice'),);
}

sub action_create_invoice {
  my ($self) = @_;
  my %myconfig = %main::myconfig;

  $self->transaction(SL::DB::Manager::BankTransaction->find_by(id => $::form->{bt_id}));

  my $vendor_of_transaction = SL::DB::Manager::Vendor->find_by(iban => $self->transaction->{remote_account_number});
  my $use_vendor_filter     = $self->transaction->{remote_account_number} && $vendor_of_transaction;

  my $templates_ap = SL::DB::Manager::RecordTemplate->get_all(
    where        => [ template_type => 'ap_transaction' ],
    with_objects => [ qw(employee vendor) ],
  );
  my $templates_gl = SL::DB::Manager::RecordTemplate->get_all(
    query        => [ template_type => 'gl_transaction',
                      chart_id      => SL::DB::Manager::BankAccount->find_by(id => $self->transaction->local_bank_account_id)->chart_id,
                    ],
    with_objects => [ qw(employee record_template_items) ],
  );

  # pre filter templates_ap, if we have a vendor match (IBAN eq IBAN) - show and allow user to edit this via gui!
  $templates_ap = [ grep { $_->vendor_id == $vendor_of_transaction->id } @{ $templates_ap } ] if $use_vendor_filter;

  $self->callback($self->url_for(
    action                => 'list',
    'filter.bank_account' => $::form->{filter}->{bank_account},
    'filter.todate'       => $::form->{filter}->{todate},
    'filter.fromdate'     => $::form->{filter}->{fromdate},
  ));

  $self->render(
    'bank_transactions/create_invoice',
    { layout => 0 },
    title        => t8('Create invoice'),
    TEMPLATES_GL => $use_vendor_filter && @{ $templates_ap } ? undef : $templates_gl,
    TEMPLATES_AP => $templates_ap,
    vendor_name  => $use_vendor_filter && @{ $templates_ap } ? $vendor_of_transaction->name : undef,
  );
}

sub action_ajax_payment_suggestion {
  my ($self) = @_;

  # based on a BankTransaction ID and a Invoice or PurchaseInvoice ID passed via $::form,
  # create an HTML blob to be used by the js function add_invoices in templates/webpages/bank_transactions/list.html
  # and return encoded as JSON

  croak("Need bt_id") unless $::form->{bt_id};

  my $invoice = SL::DB::Manager::Invoice->find_by( id => $::form->{prop_id} ) || SL::DB::Manager::PurchaseInvoice->find_by( id => $::form->{prop_id} );

  croak("No valid invoice found") unless $invoice;

  my $html = $self->render(
    'bank_transactions/_payment_suggestion', { output => 0 },
    bt_id          => $::form->{bt_id},
    invoice        => $invoice,
  );

  $self->render(\ SL::JSON::to_json( { 'html' => "$html" } ), { layout => 0, type => 'json', process => 0 });
};

sub action_filter_templates {
  my ($self) = @_;

  $self->{transaction}      = SL::DB::Manager::BankTransaction->find_by(id => $::form->{bt_id});

  my (@filter, @filter_ap);

  # filter => gl and ap | filter_ap = ap (i.e. vendorname)
  push @filter,    ('template_name' => { ilike => '%' . $::form->{template} . '%' })  if $::form->{template};
  push @filter,    ('reference'     => { ilike => '%' . $::form->{reference} . '%' }) if $::form->{reference};
  push @filter_ap, ('vendor.name'   => { ilike => '%' . $::form->{vendor} . '%' })    if $::form->{vendor};
  push @filter_ap, @filter;
  my $templates_gl = SL::DB::Manager::RecordTemplate->get_all(
    query        => [ template_type => 'gl_transaction',
                      chart_id      => SL::DB::Manager::BankAccount->find_by(id => $self->transaction->local_bank_account_id)->chart_id,
                      (and => \@filter) x !!@filter
                    ],
    with_objects => [ qw(employee record_template_items) ],
  );

  my $templates_ap = SL::DB::Manager::RecordTemplate->get_all(
    where        => [ template_type => 'ap_transaction', (and => \@filter_ap) x !!@filter_ap ],
    with_objects => [ qw(employee vendor) ],
  );
  $::form->{filter} //= {};

  $self->callback($self->url_for(
    action                => 'list',
    'filter.bank_account' => $::form->{filter}->{bank_account},
    'filter.todate'       => $::form->{filter}->{todate},
    'filter.fromdate'     => $::form->{filter}->{fromdate},
  ));

  my $output  = $self->render(
    'bank_transactions/_template_list',
    { output => 0 },
    TEMPLATES_AP => $templates_ap,
    TEMPLATES_GL => $templates_gl,
  );

  $self->render(\to_json({ html => $output }), { type => 'json', process => 0 });
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

  my $all_open_ar_invoices = SL::DB::Manager::Invoice        ->get_all(where => \@where_sale,     with_objects => 'customer');
  my $all_open_ap_invoices = SL::DB::Manager::PurchaseInvoice->get_all(where => \@where_purchase, with_objects => 'vendor');

  my @all_open_invoices = @{ $all_open_ar_invoices };
  # add ap invoices, filtering out subcent open amounts
  push @all_open_invoices, grep { abs($_->amount - $_->paid) >= 0.01 } @{ $all_open_ap_invoices };

  @all_open_invoices = sort { $a->id <=> $b->id } @all_open_invoices;

  my $output  = $self->render(
    'bank_transactions/add_list',
    { output => 0 },
    INVOICES => \@all_open_invoices,
  );

  my %result = ( count => 0, html => $output );

  $self->render(\to_json(\%result), { type => 'json', process => 0 });
}

sub action_ajax_accept_invoices {
  my ($self) = @_;

  my @selected_invoices;
  foreach my $invoice_id (@{ $::form->{invoice_id} || [] }) {
    my $invoice_object = SL::DB::Manager::Invoice->find_by(id => $invoice_id) || SL::DB::Manager::PurchaseInvoice->find_by(id => $invoice_id);
    push @selected_invoices, $invoice_object;
  }

  $self->render(
    'bank_transactions/invoices',
    { layout => 0 },
    INVOICES => \@selected_invoices,
    bt_id    => $::form->{bt_id},
  );
}

sub save_invoices {
  my ($self) = @_;

  return 0 if !$::form->{invoice_ids};

  my %invoice_hash = %{ delete $::form->{invoice_ids} };  # each key (the bt line with a bt_id) contains an array of invoice_ids

  # e.g. three partial payments with bt_ids 54, 55 and 56 for invoice with id 74:
  # $invoice_hash = {
  #         '55' => [
  #                 '74'
  #               ],
  #         '54' => [
  #                 '74'
  #               ],
  #         '56' => [
  #                 '74'
  #               ]
  #       };
  #
  # or if the payment with bt_id 44 is used to pay invoices with ids 50, 51 and 52
  # $invoice_hash = {
  #           '44' => [ '50', '51', 52' ]
  #         };

  $::form->{invoice_skontos} ||= {}; # hash of arrays containing the payment types, could be empty

  # a bank_transaction may be assigned to several invoices, i.e. a customer
  # might pay several open invoices with one transaction

  $self->problems([]);

  my $count = 0;

  if ( $::form->{proposal_ids} ) {
    foreach (@{ $::form->{proposal_ids} }) {
      my  $bank_transaction_id = $_;
      my  $invoice_ids = $invoice_hash{$_};
      push @{ $self->problems }, $self->save_single_bank_transaction(
        bank_transaction_id => $bank_transaction_id,
        invoice_ids         => $invoice_ids,
        sources             => ($::form->{sources} // {})->{$_},
        memos               => ($::form->{memos}   // {})->{$_},
      );
      $count += scalar( @{$invoice_ids} );
    }
  } else {
    while ( my ($bank_transaction_id, $invoice_ids) = each(%invoice_hash) ) {
      push @{ $self->problems }, $self->save_single_bank_transaction(
        bank_transaction_id => $bank_transaction_id,
        invoice_ids         => $invoice_ids,
        sources             => [  map { $::form->{"sources_${bank_transaction_id}_${_}"} } @{ $invoice_ids } ],
        memos               => [  map { $::form->{"memos_${bank_transaction_id}_${_}"}   } @{ $invoice_ids } ],
      );
      $count += scalar( @{$invoice_ids} );
    }
  }
  my $max_count = $count;
  foreach (@{ $self->problems }) {
    $count-- if $_->{result} eq 'error';
  }
  return ($count, $max_count);
}

sub action_save_invoices {
  my ($self) = @_;
  my ($success_count, $max_count) = $self->save_invoices();

  if ($success_count == $max_count) {
    flash('ok', t8('#1 invoice(s) saved.', $success_count));
  } else {
    flash('error', t8('At least #1 invoice(s) not saved', $max_count - $success_count));
  }

  $self->action_list();
}

sub action_save_proposals {
  my ($self) = @_;

  if ( $::form->{proposal_ids} ) {
    my $propcount = scalar(@{ $::form->{proposal_ids} });
    if ( $propcount > 0 ) {
      my $count = $self->save_invoices();

      flash('ok', t8('#1 proposal(s) with #2 invoice(s) saved.',  $propcount, $count));
    }
  }
  $self->action_list();

}

sub save_single_bank_transaction {
  my ($self, %params) = @_;

  my %data = (
    %params,
    bank_transaction => SL::DB::Manager::BankTransaction->find_by(id => $params{bank_transaction_id}),
    invoices         => [],
  );

  if (!$data{bank_transaction}) {
    return {
      %data,
      result => 'error',
      message => $::locale->text('The ID #1 is not a valid database ID.', $data{bank_transaction_id}),
    };
  }

  my $bank_transaction = $data{bank_transaction};

  if ($bank_transaction->closed_period) {
    return {
      %data,
      result => 'error',
      message => $::locale->text('Cannot post payment for a closed period!'),
    };
  }
  my (@warnings);

  my $worker = sub {
    my $bt_id                 = $data{bank_transaction_id};
    my $sign                  = $bank_transaction->amount < 0 ? -1 : 1;
    my $payment_received      = $bank_transaction->amount > 0;
    my $payment_sent          = $bank_transaction->amount < 0;


    foreach my $invoice_id (@{ $params{invoice_ids} }) {
      my $invoice = SL::DB::Manager::Invoice->find_by(id => $invoice_id) || SL::DB::Manager::PurchaseInvoice->find_by(id => $invoice_id);
      if (!$invoice) {
        return {
          %data,
          result  => 'error',
          message => $::locale->text("The ID #1 is not a valid database ID.", $invoice_id),
        };
      }
      push @{ $data{invoices} }, $invoice;
    }

    if (   $payment_received
        && any {    ( $_->is_sales && ($_->amount < 0))
                 || (!$_->is_sales && ($_->amount > 0))
               } @{ $data{invoices} }) {
      return {
        %data,
        result  => 'error',
        message => $::locale->text("Received payments can only be posted for sales invoices and purchase credit notes."),
      };
    }

    if (   $payment_sent
        && any {    ( $_->is_sales && ($_->amount > 0))
                 || (!$_->is_sales && ($_->amount < 0) && ($_->invoice_type eq 'purchase_invoice'))
               } @{ $data{invoices} }) {
      return {
        %data,
        result  => 'error',
        message => $::locale->text("Sent payments can only be posted for purchase invoices and sales credit notes."),
      };
    }

    my $max_invoices = scalar(@{ $data{invoices} });
    my $n_invoices   = 0;

    foreach my $invoice (@{ $data{invoices} }) {
      my $source = ($data{sources} // [])->[$n_invoices];
      my $memo   = ($data{memos}   // [])->[$n_invoices];

      $n_invoices++ ;
      # safety check invoice open
      croak("Invoice closed. Cannot proceed.") unless ($invoice->open_amount);

      if (   ($payment_sent     && $bank_transaction->not_assigned_amount >= 0)
          || ($payment_received && $bank_transaction->not_assigned_amount <= 0)) {
        return {
          %data,
          result  => 'error',
          message => $::locale->text("A payment can only be posted for multiple invoices if the amount to post is equal to or bigger than the sum of the open amounts of the affected invoices."),
        };
      }

      my ($payment_type, $free_skonto_amount);
      if ( defined $::form->{invoice_skontos}->{"$bt_id"} ) {
        $payment_type = shift(@{ $::form->{invoice_skontos}->{"$bt_id"} });
      } else {
        $payment_type = 'without_skonto';
      }

      if ($payment_type eq 'free_skonto') {
        # parse user input > 0
        if ($::form->parse_amount(\%::myconfig, $::form->{"free_skonto_amount"}->{"$bt_id"}{$invoice->id}) > 0) {
          $free_skonto_amount = $::form->parse_amount(\%::myconfig, $::form->{"free_skonto_amount"}->{"$bt_id"}{$invoice->id});
        } else {
          return {
            %data,
            result  => 'error',
            message => $::locale->text("Free skonto amount has to be a positive number."),
          };
        }
      }
    # pay invoice
    # TODO rewrite this: really booked amount should be a return value of Payment.pm
    # also this controller shouldnt care about how to calc skonto. we simply delegate the
    # payment_type to the helper and get the corresponding bank_transaction values back
    # hotfix to get the signs right - compare absolute values and later set the signs
    # should be better done elsewhere - changing not_assigned_amount to abs feels seriously bogus

    my $open_amount = $payment_type eq 'with_skonto_pt' ? $invoice->amount_less_skonto : $invoice->open_amount;
    $open_amount            = abs($open_amount);
    $open_amount           -= $free_skonto_amount if ($payment_type eq 'free_skonto');
    my $not_assigned_amount = abs($bank_transaction->not_assigned_amount);
    my $amount_for_booking  = ($open_amount < $not_assigned_amount) ? $open_amount : $not_assigned_amount;
    my $amount_for_payment  = $amount_for_booking;

    # get the right direction for the payment bookings (all amounts < 0 are stornos, credit notes or negative ap)
    $amount_for_payment *= -1 if $invoice->amount < 0;
    $free_skonto_amount *= -1 if ($free_skonto_amount && $invoice->amount < 0);
    # get the right direction for the bank transaction
    $amount_for_booking *= $sign;

    $bank_transaction->invoice_amount($bank_transaction->invoice_amount + $amount_for_booking);

    # ... and then pay the invoice
    my @acc_ids = $invoice->pay_invoice(chart_id => $bank_transaction->local_bank_account->chart_id,
                          trans_id      => $invoice->id,
                          amount        => $amount_for_payment,
                          payment_type  => $payment_type,
                          source        => $source,
                          memo          => $memo,
                          skonto_amount => $free_skonto_amount,
                          transdate     => $bank_transaction->valutadate->to_kivitendo);
    # ... and record the origin via BankTransactionAccTrans
    if (scalar(@acc_ids) < 2) {
      return {
        %data,
        result  => 'error',
        message => $::locale->text("Unable to book transactions for bank purpose #1", $bank_transaction->purpose),
      };
    }
    foreach my $acc_trans_id (@acc_ids) {
        my $id_type = $invoice->is_sales ? 'ar' : 'ap';
        my  %props_acc = (
          acc_trans_id        => $acc_trans_id,
          bank_transaction_id => $bank_transaction->id,
          $id_type            => $invoice->id,
        );
        SL::DB::BankTransactionAccTrans->new(%props_acc)->save;
    }
      # Record a record link from the bank transaction to the invoice
      my %props = (
        from_table => 'bank_transactions',
        from_id    => $bt_id,
        to_table   => $invoice->is_sales ? 'ar' : 'ap',
        to_id      => $invoice->id,
      );
      SL::DB::RecordLink->new(%props)->save;

      # "close" a sepa_export_item if it exists
      # code duplicated in action_save_proposals!
      # currently only works, if there is only exactly one open sepa_export_item
      if ( my $seis = $invoice->find_sepa_export_items({ executed => 0 }) ) {
        if ( scalar @$seis == 1 ) {
          # moved the execution and the check for sepa_export into a method,
          # this isn't part of a transaction, though
          $seis->[0]->set_executed if $invoice->id == $seis->[0]->arap_id;
        }
      }

    }
    $bank_transaction->save;

    # 'undef' means 'no error' here.
    return undef;
  };

  my $error;
  my $rez = $data{bank_transaction}->db->with_transaction(sub {
    eval {
      $error = $worker->();
      1;

    } or do {
      $error = {
        %data,
        result  => 'error',
        message => $@,
      };
    };

    # Rollback Fehler nicht weiterreichen
    # die if $error;
    # aber einen rollback von hand
    $::lxdebug->message(LXDebug->DEBUG2(),"finish worker with ". ($error ? $error->{result} : '-'));
    $data{bank_transaction}->db->dbh->rollback if $error && $error->{result} eq 'error';
  });

  return grep { $_ } ($error, @warnings);
}
sub action_unlink_bank_transaction {
  my ($self, %params) = @_;

  croak("No bank transaction ids") unless scalar @{ $::form->{ids}} > 0;

  my $success_count;

  foreach my $bt_id (@{ $::form->{ids}} )  {

    my $bank_transaction = SL::DB::Manager::BankTransaction->find_by(id => $bt_id);
    croak("No valid bank transaction found") unless (ref($bank_transaction)  eq 'SL::DB::BankTransaction');
    croak t8('Cannot unlink payment for a closed period!') if $bank_transaction->closed_period;

    # everything in one transaction
    my $rez = $bank_transaction->db->with_transaction(sub {
      # 1. remove all reconciliations (due to underlying trigger, this has to be the first step)
      my $rec_links = SL::DB::Manager::ReconciliationLink->get_all(where => [ bank_transaction_id => $bt_id ]);
      $_->delete for @{ $rec_links };

      my %trans_ids;
      foreach my $acc_trans_id_entry (@{ SL::DB::Manager::BankTransactionAccTrans->get_all(where => [bank_transaction_id => $bt_id ] )}) {

        my $acc_trans = SL::DB::Manager::AccTransaction->get_all(where => [acc_trans_id => $acc_trans_id_entry->acc_trans_id]);

        # save trans_id and type
        die "no type" unless ($acc_trans_id_entry->ar_id || $acc_trans_id_entry->ap_id || $acc_trans_id_entry->gl_id);
        $trans_ids{$acc_trans_id_entry->ar_id} = 'ar' if $acc_trans_id_entry->ar_id;
        $trans_ids{$acc_trans_id_entry->ap_id} = 'ap' if $acc_trans_id_entry->ap_id;
        $trans_ids{$acc_trans_id_entry->gl_id} = 'gl' if $acc_trans_id_entry->gl_id;
        # 2. all good -> ready to delete acc_trans and bt_acc link
        $acc_trans_id_entry->delete;
        $_->delete for @{ $acc_trans };
      }
      # 3. update arap.paid (may not be 0, yet)
      #    or in case of gl, delete whole entry
      while (my ($trans_id, $type) = each %trans_ids) {
        if ($type eq 'gl') {
          SL::DB::Manager::GLTransaction->delete_all(where => [ id => $trans_id ]);
          next;
        }
        die ("invalid type") unless $type =~ m/^(ar|ap)$/;

        # recalc and set paid via database query
        my $query = qq|UPDATE $type SET paid =
                        (SELECT COALESCE(abs(sum(amount)),0) FROM acc_trans
                         WHERE trans_id = ?
                         AND chart_link ilike '%paid%')
                       WHERE id = ?|;

        die if (do_query($::form, $bank_transaction->db->dbh, $query, $trans_id, $trans_id) == -1);
      }
      # 4. and delete all (if any) record links
      my $rl = SL::DB::Manager::RecordLink->delete_all(where => [ from_id => $bt_id, from_table => 'bank_transactions' ]);

      # 5. finally reset  this bank transaction
      $bank_transaction->invoice_amount(0);
      $bank_transaction->cleared(0);
      $bank_transaction->save;
      # 6. and add a log entry in history_erp
      SL::DB::History->new(
        trans_id    => $bank_transaction->id,
        snumbers    => 'bank_transaction_unlink_' . $bank_transaction->id,
        employee_id => SL::DB::Manager::Employee->current->id,
        what_done   => 'bank_transaction',
        addition    => 'UNLINKED',
      )->save();

      1;

    }) || die t8('error while unlinking payment #1 : ', $bank_transaction->purpose) . $bank_transaction->db->error . "\n";

    $success_count++;
  }

  flash('ok', t8('#1 bank transaction bookings undone.', $success_count));
  $self->action_list_all() unless $params{testcase};
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
    [ $filter->{"transdate:date::ge"},      $::locale->text('Transdate')  . " " . $::locale->text('From Date') ],
    [ $filter->{"transdate:date::le"},      $::locale->text('Transdate')  . " " . $::locale->text('To Date')   ],
    [ $filter->{"valutadate:date::ge"},     $::locale->text('Valutadate') . " " . $::locale->text('From Date') ],
    [ $filter->{"valutadate:date::le"},     $::locale->text('Valutadate') . " " . $::locale->text('To Date')   ],
    [ $filter->{"amount:number"},           $::locale->text('Amount')                                          ],
    [ $filter->{"bank_account_id:integer"}, $::locale->text('Local bank account')                              ],
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

  my @columns     = qw(ids local_bank_name transdate valudate remote_name remote_account_number remote_bank_code amount invoice_amount invoices currency purpose local_account_number local_bank_code id);
  my @sortable    = qw(local_bank_name transdate valudate remote_name remote_account_number remote_bank_code amount                                  purpose local_account_number local_bank_code);

  my %column_defs = (
    ids                 => { raw_header_data => checkbox_tag("", id => "check_all", checkall  => "[data-checkall=1]"),
                             'align'         => 'center',
                             raw_data        => sub { if (@{ $_[0]->linked_invoices }) {
                                                        if ($_[0]->closed_period) {
                                                          html_tag('text', "X"); #, tooltip => t8('Bank Transaction is in a closed period.')),
                                                        } else {
                                                          checkbox_tag("ids[]", value => $_[0]->id, "data-checkall" => 1);
                                                        }
                                                } } },
    transdate             => { sub   => sub { $_[0]->transdate_as_date } },
    valutadate            => { sub   => sub { $_[0]->valutadate_as_date } },
    remote_name           => { },
    remote_account_number => { },
    remote_bank_code      => { },
    amount                => { sub   => sub { $_[0]->amount_as_number },
                               align => 'right' },
    invoice_amount        => { sub   => sub { $_[0]->invoice_amount_as_number },
                               align => 'right' },
    invoices              => { sub   => sub { my @invnumbers; for my $obj (@{ $_[0]->linked_invoices }) {
                                                                next unless $obj; push @invnumbers, $obj->invnumber } return \@invnumbers } },
    currency              => { sub   => sub { $_[0]->currency->name } },
    purpose               => { },
    local_account_number  => { sub   => sub { $_[0]->local_bank_account->account_number } },
    local_bank_code       => { sub   => sub { $_[0]->local_bank_account->bank_code } },
    local_bank_name       => { sub   => sub { $_[0]->local_bank_account->name } },
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

sub init_problems { [] }

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    sorted     => {
      _default => {
        by  => 'transdate',
        dir => 0,   # 1 = ASC, 0 = DESC : default sort is newest at top
      },
      id                    => t8('ID'),
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

sub load_ap_record_template_url {
  my ($self, $template) = @_;

  return $self->url_for(
    controller                           => 'ap.pl',
    action                               => 'load_record_template',
    id                                   => $template->id,
    'form_defaults.amount_1'             => $::form->format_amount(\%::myconfig, -1 * $self->transaction->amount, 2),
    'form_defaults.transdate'            => $self->transaction->transdate_as_date,
    'form_defaults.duedate'              => $self->transaction->transdate_as_date,
    'form_defaults.no_payment_bookings'  => 1,
    'form_defaults.paid_1_suggestion'    => $::form->format_amount(\%::myconfig, -1 * $self->transaction->amount, 2),
    'form_defaults.AP_paid_1_suggestion' => $self->transaction->local_bank_account->chart->accno,
    'form_defaults.callback'             => $self->callback,
  );
}

sub load_gl_record_template_url {
  my ($self, $template) = @_;

  return $self->url_for(
    controller                           => 'gl.pl',
    action                               => 'load_record_template',
    id                                   => $template->id,
    'form_defaults.amount_1'             => abs($self->transaction->not_assigned_amount), # always positive
    'form_defaults.transdate'            => $self->transaction->transdate_as_date,
    'form_defaults.callback'             => $self->callback,
    'form_defaults.bt_id'                => $self->transaction->id,
    'form_defaults.bt_chart_id'          => $self->transaction->local_bank_account->chart->id,
    'form_defaults.description'          => $self->transaction->purpose,
  );
}

sub setup_search_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Filter'),
        submit    => [ '#search_form', { action => 'BankTransaction/list' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_list_all_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [ t8('Actions') ],
        action => [
          t8('Unlink bank transactions'),
            submit => [ '#form', { action => 'BankTransaction/unlink_bank_transaction' } ],
            checks => [ [ 'kivi.check_if_entries_selected', '[name="ids[]"]' ] ],
            disabled  => $::instance_conf->get_payments_changeable ? t8('Cannot safely unlink bank transactions, please set the posting configuration for payments to unchangeable.') : undef,
          ],
        ],
        action => [
          t8('Filter'),
          submit    => [ '#filter_form', { action => 'BankTransaction/list_all' } ],
        accesskey => 'enter',
      ],
    );
  }
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::BankTransaction - Posting payments to invoices from
bank transactions imported earlier

=head1 FUNCTIONS

=over 4

=item C<save_single_bank_transaction %params>

Takes a bank transaction ID (as parameter C<bank_transaction_id> and
tries to post its amount to a certain number of invoices (parameter
C<invoice_ids>, an array ref of database IDs to purchase or sales
invoice objects).

This method handles already partly assigned bank transactions.

This method cannot handle already partly assigned bank transactions, i.e.
a bank transaction that has a invoice_amount <> 0 but not the fully
transaction amount (invoice_amount == amount).

If the amount of the bank transaction is higher than the sum of
the assigned invoices (1 .. n) the bank transaction will only be
partly assigned.

The whole function is wrapped in a database transaction. If an
exception occurs the bank transaction is not posted at all. The same
is true if the code detects an error during the execution, e.g. a bank
transaction that's already been posted earlier. In both cases the
database transaction will be rolled back.

If warnings but not errors occur the database transaction is still
committed.

The return value is an error object or C<undef> if the function
succeeded. The calling function will collect all warnings and errors
and display them in a nicely formatted table if any occurred.

An error object is a hash reference containing the following members:

=over 2

=item * C<result> — can be either C<warning> or C<error>. Warnings are
displayed slightly different than errors.

=item * C<message> — a human-readable message included in the list of
errors meant as the description of why the problem happened

=item * C<bank_transaction_id>, C<invoice_ids> — the same parameters
that the function was called with

=item * C<bank_transaction> — the database object
(C<SL::DB::BankTransaction>) corresponding to C<bank_transaction_id>

=item * C<invoices> — an array ref of the database objects (either
C<SL::DB::Invoice> or C<SL::DB::PurchaseInvoice>) corresponding to
C<invoice_ids>

=back

=item C<action_unlink_bank_transaction>

Takes one or more bank transaction ID (as parameter C<form::ids>) and
tries to revert all payment bookings including already cleared bookings.

This method won't undo payments that are in a closed period and assumes
that payments are not manually changed, i.e. only imported payments.

GL-records will be deleted completely if a bank transaction was the source.

TODO: we still rely on linked_records for the check boxes

=back

=head1 AUTHOR

Niclas Zimmermann E<lt>niclas@kivitendo-premium.deE<gt>,
Geoffrey Richardson E<lt>information@richardson-bueren.deE<gt>

=cut
