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

  my $bank_accounts = SL::DB::Manager::BankAccount->get_all();

  $self->render('bank_transactions/search',
                 label_sub => sub { t8('#1 - Account number #2, bank code #3, #4', $_[0]->name, $_[0]->account_number, $_[0]->bank_code, $_[0]->bank, )},
                 BANK_ACCOUNTS => $bank_accounts);
}

sub action_list_all {
  my ($self) = @_;

  my $transactions = $self->models->get;

  $self->make_filter_summary;
  $self->prepare_report;

  $self->report_generator_list_objects(report => $self->{report}, objects => $transactions);
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

  my $fromdate = $::locale->parse_date_to_object(\%::myconfig, $::form->{filter}->{fromdate});
  my $todate   = $::locale->parse_date_to_object(\%::myconfig, $::form->{filter}->{todate});
  $todate->add( days => 1 ) if $todate;

  my @where = ();
  push @where, (transdate => { ge => $fromdate }) if ($fromdate);
  push @where, (transdate => { lt => $todate })   if ($todate);

  my $bank_transactions = SL::DB::Manager::BankTransaction->get_all(where => [ amount => {ne => \'invoice_amount'},
                                                                               local_bank_account_id => $::form->{filter}{bank_account},
                                                                               @where ],
                                                                    with_objects => [ 'local_bank_account', 'currency' ],
                                                                    sort_by => $sort_by, limit => 10000);

  my $all_open_ar_invoices = SL::DB::Manager::Invoice->get_all(where => [amount => { gt => \'paid' }], with_objects => 'customer');
  my $all_open_ap_invoices = SL::DB::Manager::PurchaseInvoice->get_all(where => [amount => { gt => \'paid' }], with_objects => 'vendor');

  my @all_open_invoices;
  push @all_open_invoices, @{ $all_open_ar_invoices };
  push @all_open_invoices, @{ $all_open_ap_invoices };

  foreach my $bt (@{ $bank_transactions }) {
    next unless $bt->{remote_name};  # bank has no name, usually fees, use create invoice to assign
    foreach my $open_invoice (@all_open_invoices){
      $open_invoice->{agreement} = 0;

      #compare banking arrangements
      my ($bank_code, $account_number);
      $bank_code      = $open_invoice->customer->bank_code      if $open_invoice->is_sales;
      $account_number = $open_invoice->customer->account_number if $open_invoice->is_sales;
      $bank_code      = $open_invoice->vendor->bank_code        if ! $open_invoice->is_sales;
      $account_number = $open_invoice->vendor->account_number   if ! $open_invoice->is_sales;
      ($bank_code eq $bt->remote_bank_code
        && $account_number eq $bt->remote_account_number) ? ($open_invoice->{agreement} += 2) : ();

      my $datediff = $bt->transdate->{utc_rd_days} - $open_invoice->transdate->{utc_rd_days};
      $open_invoice->{datediff} = $datediff;

      #compare amount
#      (abs($open_invoice->amount) == abs($bt->amount)) ? ($open_invoice->{agreement} += 2) : ();
# do we need double abs here? 
      (abs(abs($open_invoice->amount) - abs($bt->amount)) < 0.01) ? ($open_invoice->{agreement} += 4) : ();

      #search invoice number in purpose
      my $invnumber = $open_invoice->invnumber;
# possible improvement: match has to have more than 1 character?
      $bt->purpose =~ /\b$invnumber\b/i ? ($open_invoice->{agreement} += 2) : ();

      #check sign
      if ( $open_invoice->is_sales && $bt->amount < 0 ) {
        $open_invoice->{agreement} -= 1;
      };
      if ( ! $open_invoice->is_sales && $bt->amount > 0 ) {
        $open_invoice->{agreement} -= 1;
      };

      #search customer/vendor number in purpose
      my $cvnumber;
      $cvnumber = $open_invoice->customer->customernumber if $open_invoice->is_sales;
      $cvnumber = $open_invoice->vendor->vendornumber     if ! $open_invoice->is_sales;
      $bt->purpose =~ /\b$cvnumber\b/i ? ($open_invoice->{agreement}++) : ();

      #compare customer/vendor name and account holder
      my $cvname;
      $cvname = $open_invoice->customer->name if $open_invoice->is_sales;
      $cvname = $open_invoice->vendor->name   if ! $open_invoice->is_sales;
      $bt->remote_name =~ /\b$cvname\b/i ? ($open_invoice->{agreement}++) : ();

      #Compare transdate of bank_transaction with transdate of invoice
      #Check if words in remote_name appear in cvname
      $open_invoice->{agreement} += &check_string($bt->remote_name,$cvname);

      $open_invoice->{agreement} -= 1 if $datediff < -5; # dies hebelt eventuell Vorkasse aus
      $open_invoice->{agreement} += 1 if $datediff < 30; # dies hebelt eventuell Vorkasse aus

      # only if we already have a good agreement, let date further change value of agreement.
      # this is so that if there are several open invoices which are all equal (rent jan, rent feb...) the one with the best date match is chose over the others
      # another way around this is to just pre-filter by periods instead of matching everything
      if ( $open_invoice->{agreement} > 5 ) {
        if ( $datediff == 0 ) { 
          $open_invoice->{agreement} += 3;
        } elsif  ( $datediff > 0 and $datediff <= 14 ) {
          $open_invoice->{agreement} += 2;
        } elsif  ( $datediff >14 and $datediff < 35) {
          $open_invoice->{agreement} += 1;
        } elsif  ( $datediff >34 and $datediff < 120) {
          $open_invoice->{agreement} += 1;
        } elsif  ( $datediff < 0 ) {
          $open_invoice->{agreement} -= 1;
        } else {
          # e.g. datediff > 120
        };
      };

      #if ($open_invoice->transdate->{utc_rd_days} == $bt->transdate->{utc_rd_days}) {  
        #$open_invoice->{agreement} += 4;
        #print FH "found matching date for invoice " . $open_invoice->invnumber . " ( " . $bt->transdate->{utc_rd_days} . " . \n";
      #} elsif (($open_invoice->transdate->{utc_rd_days} + 30) < $bt->transdate->{utc_rd_days}) {  
        #$open_invoice->{agreement} -= 1;
      #} else {
        #$open_invoice->{agreement} -= 2;
        #print FH "found nomatch date -2 for invoice " . $open_invoice->invnumber . " ( " . $bt->transdate->{utc_rd_days} . " . \n";
      #};
      #print FH "agreement after date_agreement: " . $open_invoice->{agreement} . "\n";



    }
# finished going through all open_invoices

    # go through each bt
    # for each open_invoice try to match it to each open_invoice and store agreement in $open_invoice->{agreement} (which gets overwritten each time for each bt)
    #    calculate 
#  

    $bt->{proposals} = [];
    my $agreement = 11;
    # wird nie ausgeführt, bzw. nur ganz am Ende
# oder einmal am Anfang?
# es werden maximal 7 vorschläge gemacht?
    # 7 mal wird geprüft, ob etwas passt
    while (scalar @{ $bt->{proposals} } < 1 && $agreement-- > 0) {
      $bt->{proposals} = [ grep { $_->{agreement} > $agreement } @all_open_invoices ];
      #Kann wahrscheinlich weg:
#      map { $_->{style} = "green" } @{ $bt->{proposals} } if $agreement >= 5;
#      map { $_->{style} = "orange" } @{ $bt->{proposals} } if $agreement < 5 and $agreement >= 3;
#      map { $_->{style} = "red" } @{ $bt->{proposals} } if $agreement < 3;
      $bt->{agreement} = $agreement;  # agreement value at cutoff, will correspond to several results if threshold is 7 and several are already above 7
    }
  }  # finished one bt
  # finished all bt

  # separate filter for proposals (second tab, agreement >= 5 and exactly one match)
  # to qualify as a proposal there has to be
  # * agreement >= 5
  # * there must be only one exact match 
  # * depending on whether sales or purchase the amount has to have the correct sign (so Gutschriften don't work?)

  my @proposals = grep { $_->{agreement} >= 5
                         and 1 == scalar @{ $_->{proposals} }
                         and (@{ $_->{proposals} }[0]->is_sales ? abs(@{ $_->{proposals} }[0]->amount - $_->amount) < 0.01  : abs(@{ $_->{proposals} }[0]->amount + $_->amount) < 0.01) } @{ $bank_transactions };

  #Sort bank transactions by quality of proposal
  $bank_transactions = [ sort { $a->{agreement} <=> $b->{agreement} } @{ $bank_transactions } ] if $::form->{sort_by} eq 'proposal' and $::form->{sort_dir} == 1;
  $bank_transactions = [ sort { $b->{agreement} <=> $a->{agreement} } @{ $bank_transactions } ] if $::form->{sort_by} eq 'proposal' and $::form->{sort_dir} == 0;


  $self->render('bank_transactions/list',
                title             => t8('List of bank transactions'),
                BANK_TRANSACTIONS => $bank_transactions,
                PROPOSALS         => \@proposals,
                bank_account      => SL::DB::Manager::BankAccount->find_by(id => $::form->{filter}{bank_account}) );
}

sub check_string {
    my $bankstring = shift;
    my $namestring = shift;
    return 0 unless $bankstring and $namestring;

    my @bankwords = grep(/^\w+$/, split(/\b/,$bankstring));

    my $match = 0;
    foreach my $bankword ( @bankwords ) {
        # only try to match strings with more than 2 characters
        next unless length($bankword)>2; 
        if ( $namestring =~ /\b$bankword\b/i ) {
            $match++;
        };
    };
    return $match;
};

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
    push @where_sale,     (invnumber => { ilike => '%' . $::form->{invnumber} . '%'});
    push @where_purchase, (invnumber => { ilike => '%' . $::form->{invnumber} . '%'});
  }

  if ($::form->{amount}) {
    push @where_sale,     (amount => $::form->parse_amount(\%::myconfig, $::form->{amount}));
    push @where_purchase, (amount => $::form->parse_amount(\%::myconfig, $::form->{amount}));
  }

  if ($::form->{vcnumber}) {
    push @where_sale,     ('customer.customernumber' => { ilike => '%' . $::form->{vcnumber} . '%'});
    push @where_purchase, ('vendor.vendornumber'     => { ilike => '%' . $::form->{vcnumber} . '%'});
  }

  if ($::form->{vcname}) {
    push @where_sale,     ('customer.name' => { ilike => '%' . $::form->{vcname} . '%'});
    push @where_purchase, ('vendor.name'   => { ilike => '%' . $::form->{vcname} . '%'});
  }

  if ($::form->{transdatefrom}) {
    my $fromdate = $::locale->parse_date_to_object(\%::myconfig, $::form->{transdatefrom});
    push @where_sale,     ('transdate' => { ge => $fromdate});
    push @where_purchase, ('transdate' => { ge => $fromdate});
  }

  if ($::form->{transdateto}) {
    my $todate = $::locale->parse_date_to_object(\%::myconfig, $::form->{transdateto});
    $todate->add(days => 1);
    push @where_sale,     ('transdate' => { lt => $todate});
    push @where_purchase, ('transdate' => { lt => $todate});
  }

  my $all_open_ar_invoices = SL::DB::Manager::Invoice->get_all(where => \@where_sale, with_objects => 'customer');
  my $all_open_ap_invoices = SL::DB::Manager::PurchaseInvoice->get_all(where => \@where_purchase, with_objects => 'vendor');

  my @all_open_invoices;
  push @all_open_invoices, @{ $all_open_ar_invoices };
  push @all_open_invoices, @{ $all_open_ap_invoices };

  @all_open_invoices = sort { $a->id <=> $b->id } @all_open_invoices;
  #my $all_open_invoices = SL::DB::Manager::Invoice->get_all(where => \@where);

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

  my $invoice_hash = delete $::form->{invoice_ids};

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
      if ($amount_of_transaction == 0) {
        flash('warning',  $::locale->text('There are invoices which could not be payed by bank transaction #1 (Account number: #2, bank code: #3)!',
                                            $bank_transaction->purpose,
                                            $bank_transaction->remote_account_number,
                                            $bank_transaction->remote_bank_code));
        last;
      }
      #pay invoice or go to the next bank transaction if the amount is not sufficiently high
      if ($invoice->amount <= $amount_of_transaction) {
        $invoice->pay_invoice(chart_id => $bank_transaction->local_bank_account->chart_id, trans_id => $invoice->id, amount => $invoice->amount, transdate => $bank_transaction->transdate);
        if ($invoice->is_sales) {
          $amount_of_transaction -= $sign * $invoice->amount;
          $bank_transaction->invoice_amount($bank_transaction->invoice_amount + $invoice->amount);
        } else {
          $amount_of_transaction += $sign * $invoice->amount if (!$invoice->is_sales);
          $bank_transaction->invoice_amount($bank_transaction->invoice_amount - $invoice->amount);
        }
      } else {
        $invoice->pay_invoice(chart_id => $bank_transaction->local_bank_account->chart_id, trans_id => $invoice->id, amount => $amount_of_transaction, transdate => $bank_transaction->transdate);
        $bank_transaction->invoice_amount($bank_transaction->amount) if $invoice->is_sales;
        $bank_transaction->invoice_amount($bank_transaction->amount) if !$invoice->is_sales;
        $amount_of_transaction = 0;
      }

      #Record a link from the bank transaction to the invoice
      my @props = (
          from_table => 'bank_transactions',
          from_id    => $bt_id,
          to_table   => $invoice->is_sales ? 'ar' : 'ap',
          to_id      => $invoice->id,
          );

      my $existing = SL::DB::Manager::RecordLink->get_all(where => \@props, limit => 1)->[0];

      SL::DB::RecordLink->new(@props)->save if !$existing;
    }
    $bank_transaction->save;
  }

  $self->action_list();
}

sub action_save_proposals {
  my ($self) = @_;

  foreach my $bt_id (@{ $::form->{proposal_ids} }) {
    #mark bt as booked
    my $bt = SL::DB::Manager::BankTransaction->find_by(id => $bt_id);
    $bt->invoice_amount($bt->amount);
    $bt->save;

    #pay invoice
    my $arap = SL::DB::Manager::Invoice->find_by(id => $::form->{"proposed_invoice_$bt_id"});
    $arap    = SL::DB::Manager::PurchaseInvoice->find_by(id => $::form->{"proposed_invoice_$bt_id"}) if not defined $arap;
    $arap->pay_invoice(chart_id  => $bt->local_bank_account->chart_id,
                       trans_id  => $arap->id,
                       amount    => $arap->amount,
                       transdate => $bt->transdate);
    $arap->save;

    #create record link
    my @props = (
        from_table => 'bank_transactions',
        from_id    => $bt_id,
        to_table   => $arap->is_sales ? 'ar' : 'ap',
        to_id      => $arap->id,
        );

    my $existing = SL::DB::Manager::RecordLink->get_all(where => \@props, limit => 1)->[0];

    SL::DB::RecordLink->new(@props)->save if !$existing;
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
    [ $filter->{"transdate:date::ge"},  $::locale->text('Transdate') . " " . $::locale->text('From Date') ],
    [ $filter->{"transdate:date::le"},  $::locale->text('Transdate') . " " . $::locale->text('To Date')   ],
    [ $filter->{"valutadate:date::ge"}, $::locale->text('Valutadate') . " " . $::locale->text('From Date') ],
    [ $filter->{"valutadate:date::le"}, $::locale->text('Valutadate') . " " . $::locale->text('To Date')   ],
    [ $filter->{"amount:number"},       $::locale->text('Amount')                                           ],
    [ $filter->{"bank_account_id:integer"}, $::locale->text('Local bank account')                                           ],
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

  my @columns     = qw(transdate valudate remote_name remote_account_number remote_bank_code amount invoice_amount invoices currency purpose local_account_number local_bank_code id);
  my @sortable    = qw(transdate valudate remote_name remote_account_number remote_bank_code amount                                  purpose local_account_number local_bank_code);

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
  $report->set_export_options(qw(list filter));
  $report->set_options_from_form;
  $self->models->disable_pagination if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->models->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);

  my $bank_accounts = SL::DB::Manager::BankAccount->get_all();
  my $label_sub = sub { t8('#1 - Account number #2, bank code #3, #4', $_[0]->name, $_[0]->account_number, $_[0]->bank_code, $_[0]->bank )};

  $report->set_options(
    raw_top_info_text     => $self->render('bank_transactions/report_top',    { output => 0 }, BANK_ACCOUNTS => $bank_accounts, label_sub => $label_sub),
    raw_bottom_info_text  => $self->render('bank_transactions/report_bottom', { output => 0 }),
  );
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    sorted => {
      _default => {
        by    => 'transdate',
        dir   => 1,
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
    },
    with_objects => [ 'local_bank_account', 'currency' ],
  );
}

1;
