use strict;

use List::MoreUtils qw(any none uniq);
use List::Util qw(sum first);
use POSIX qw(strftime);

use SL::DB::BankAccount;
use SL::DB::SepaExport;
use SL::Chart;
use SL::CT;
use SL::Form;
use SL::GenericTranslations;
use SL::Locale::String qw(t8);
use SL::ReportGenerator;
use SL::SEPA;
use SL::SEPA::XML;
use SL::SEPA::SwissXML;
use SL::Helper::QrBillParser;
use SL::Helper::ISO3166;

use SL::Helper::QrBillFunctions qw(
  get_street_name_from_address_line
  get_building_number_from_address_line
);

require "bin/mozilla/common.pl";
require "bin/mozilla/reportgenerator.pl";

sub bank_transfer_add {
  $main::lxdebug->enter_sub();

  my $form          = $main::form;
  my $locale        = $main::locale;
  my $vc            = $form->{vc} eq 'customer' ? 'customer' : 'vendor';
  my $vc_no         = $form->{vc} eq 'customer' ? $::locale->text('VN') : $::locale->text('CN');

  my $swiss_export = $::instance_conf->get_sepa_swiss_xml_export;

  $form->{title}    = $vc eq 'customer' ?
                        $::locale->text('Prepare bank collection via SEPA XML') :
                        $swiss_export ?
                          $locale->text('Prepare bank transfer via swiss XML') :
                          $locale->text('Prepare bank transfer via SEPA XML');

  my $bank_accounts = SL::DB::Manager::BankAccount->get_all_sorted( query => [ obsolete => 0 ] );

  if (!scalar @{ $bank_accounts }) {
    $form->error($locale->text('You have not added bank accounts yet.'));
  }

  my $invoices = SL::SEPA->retrieve_open_invoices(vc => $vc);

  if (!scalar @{ $invoices }) {
    $form->show_generic_information($locale->text('Either there are no open invoices, or you have already initiated bank transfers ' .
                                                  'with the open amounts for those that are still open.'));
    $main::lxdebug->leave_sub();
    return;
  }

  # Only include those per default that require manual action from our
  # side. For sales invoices these are the ones for which direct debit
  # has been selected. For purchase invoices it's the other way
  # around: if direct debit is active then the vendor will collect
  # from us automatically and we don't have to send money manually.
  $_->{checked} = ($vc eq 'customer' ? $_->{direct_debit} : !$_->{direct_debit}) for @{ $invoices };

  my $translation_list = GenericTranslations->list(translation_type => 'sepa_remittance_info_pfx');
  my %translations     = map { ( ($_->{language_id} || 'default') => $_->{translation} ) } @{ $translation_list };

  foreach my $invoice (@{ $invoices }) {
    my $prefix                    = $translations{ $invoice->{language_id} } || $translations{default} || $::locale->text('Invoice');
    $prefix                      .= ' ' unless $prefix =~ m/ $/;
    $invoice->{reference_prefix}  = $prefix;

    # add c_vendor_id or v_vendor_id as a prefix if a entry exists
    next unless $invoice->{vc_vc_id};

    my $prefix_vc_number             = $translations{ $invoice->{language_id} } || $translations{default} || $vc_no;
    $prefix_vc_number               .= ' ' unless $prefix_vc_number =~ m/ $/;
    $invoice->{reference_prefix_vc}  = ' '  . $prefix_vc_number unless $prefix_vc_number =~ m/^ /;
  }

  # for swiss export override database check because of different cases
  if ($swiss_export) {
    foreach my $invoice (@{ $invoices }) {
      # determine invoice type
      if ($invoice->{qrbill_data}) {
        $invoice->{type} = 'QRBILL';

        # vendor iban comes from qrbill data
        # no further checks needed
        $invoice->{vc_bank_info_ok} = 1;

      } elsif ($invoice->{vc_iban} =~ m/^(CH|LI)/) {
        $invoice->{type} = 'DOMESTIC';

        # vendor iban is needed
        $invoice->{vc_bank_info_ok} = $invoice->{vc_iban} ? 1 : 0;

      } else {
        $invoice->{type} = 'SEPA';

        # vendor iban and bic are needed
        $invoice->{vc_bank_info_ok} = $invoice->{vc_iban} && $invoice->{vc_bic} ? 1 : 0
      }
    }
  }

  setup_sepa_add_transfer_action_bar();

  $form->header();
  print $form->parse_html_template('sepa/bank_transfer_add',
                                   { 'INVOICES'           => $invoices,
                                     'BANK_ACCOUNTS'      => $bank_accounts,
                                     'vc'                 => $vc,
                                   });

  $main::lxdebug->leave_sub();
}

sub bank_transfer_create {
  $main::lxdebug->enter_sub();

  my $form          = $main::form;
  my $locale        = $main::locale;
  my $myconfig      = \%main::myconfig;
  my $vc            = $form->{vc} eq 'customer' ? 'customer' : 'vendor';

  my $swiss_export = $::instance_conf->get_sepa_swiss_xml_export;

  $form->{title}    = $vc eq 'customer' ?
                        $::locale->text('Create bank collection via SEPA XML') :
                        $swiss_export ?
                          $locale->text('Create bank transfer via swiss XML') :
                          $locale->text('Create bank transfer via SEPA XML');

  my $bank_accounts = SL::DB::Manager::BankAccount->get_all_sorted( query => [ obsolete => 0 ] );
  if (!scalar @{ $bank_accounts }) {
    $form->error($locale->text('You have not added bank accounts yet.'));
  }

  my $bank_account = SL::DB::Manager::BankAccount->find_by( id => $form->{bank_account} );

  unless ( $bank_account ) {
    $form->error($locale->text('The selected bank account does not exist anymore.'));
  }

  my $arap_id        = $vc eq 'customer' ? 'ar_id' : 'ap_id';
  my $invoices       = SL::SEPA->retrieve_open_invoices(vc => $vc);

  # Load all open invoices (again), but grep out the ones that were selected with checkboxes beforehand ($_->selected).
  # At this stage we again have all the invoice information, including dropdown with payment_type options.
  # All the information from retrieve_open_invoices is then ADDED to what was passed via @{ $form->{bank_transfers} }.
  # Parse amount from the entry in the form, but take skonto_amount from PT again.
  # The map inserts the values of invoice_map directly into the array of hashes.
  my %selected_ids   = map { ($_ => 1) } @{ $form->{ids} || [] };
  my %invoices_map   = map { $_->{id} => $_ } @{ $invoices };
  my @bank_transfers =
    map  +{ %{ $invoices_map{ $_->{$arap_id} } }, %{ $_ } },
    grep  { ($_->{selected} || $selected_ids{$_->{$arap_id}}) && (0 < $_->{amount}) && $invoices_map{ $_->{$arap_id} } && !($invoices_map{ $_->{$arap_id} }->{is_sepa_blocked}) }
    map   { $_->{amount} = $form->parse_amount($myconfig, $_->{amount}); $_ }
          @{ $form->{bank_transfers} || [] };

  # override default payment_type selection and set it to the one chosen by the user
  # in the previous step, so that we don't need the logic in the template
  my $subtract_days   = $::instance_conf->get_sepa_set_skonto_date_buffer_in_days;
  my $set_skonto_date = $::instance_conf->get_sepa_set_skonto_date_as_default_exec_date;
  my $set_duedate     = $::instance_conf->get_sepa_set_duedate_as_default_exec_date;
  foreach my $bt (@bank_transfers) {
    # add a good recommended exec date
    # set to skonto date if exists or to duedate
    # in both cases subtract the same buffer (if configured, default 0)
    $bt->{recommended_execution_date} =
      $set_skonto_date && $bt->{payment_type} eq 'with_skonto_pt' ?
                   DateTime->from_kivitendo($bt->{skonto_date})->subtract(days => $subtract_days)->to_kivitendo
   :  $set_duedate && $bt->{duedate}                              ?
                   DateTime->from_kivitendo($bt->{duedate}    )->subtract(days => $subtract_days)->to_kivitendo
   :  undef;


    foreach my $type ( @{$bt->{payment_select_options}} ) {
      if ( $type->{payment_type} eq $bt->{payment_type} ) {
        $type->{selected} = 1;
      } else {
        $type->{selected} = 0;
      };
    };
  };

  if (!scalar @bank_transfers) {
    $form->error($locale->text('You have selected none of the invoices.'));
  }

  my $total_trans = sum map { $_->{open_amount} } @bank_transfers;

  my ($vc_bank_info);
  my $error_message;
  my @bank_columns    = qw(iban bic);

  # separate validation for swiss export
  if (!$swiss_export) {
    push @bank_columns, qw(mandator_id mandate_date_of_signature) if $vc eq 'customer';

    if ($form->{confirmation}) {
      $vc_bank_info = { map { $_->{id} => $_ } @{ $form->{vc_bank_info} || [] } };

      foreach my $info (values %{ $vc_bank_info }) {
        if (any { !$info->{$_} } @bank_columns) {
          $error_message = $locale->text('The bank information must not be empty.');
          last;
        }
      }
    }
  } else {
    ($error_message, $vc_bank_info) = validate_vendors_swiss_export(\@bank_transfers);
  }

  if ($error_message || !$form->{confirmation}) {
    if (!$swiss_export) {
      my @vc_ids = uniq map { $_->{vc_id} } @bank_transfers;

      $vc_bank_info ||= CT->get_bank_info('vc' => $vc, 'id' => \@vc_ids);
    }

    my @vc_bank_info = sort { lc $a->{name} cmp lc $b->{name} } values %{ $vc_bank_info };

    setup_sepa_create_transfer_action_bar(is_vendor => $vc eq 'vendor');

    $form->header();
    print $form->parse_html_template('sepa/bank_transfer_create',
                                     { 'BANK_TRANSFERS'     => \@bank_transfers,
                                       'BANK_ACCOUNTS'      => $bank_accounts,
                                       'VC_BANK_INFO'       => \@vc_bank_info,
                                       'bank_account'       => $bank_account,
                                       'error_message'      => $error_message,
                                       'vc'                 => $vc,
                                       'total_trans'        => $total_trans,
                                     });

  } else {
    foreach my $bank_transfer (@bank_transfers) {
      foreach (@bank_columns) {
        $bank_transfer->{"vc_${_}"}  = $vc_bank_info->{ $bank_transfer->{vc_id} }->{$_};
        $bank_transfer->{"our_${_}"} = $bank_account->{$_};
      }

      $bank_transfer->{chart_id} = $bank_account->{chart_id};
    }

    my $id = SL::SEPA->create_export('employee'       => $::myconfig{login},
                                     'bank_transfers' => \@bank_transfers,
                                     'vc'             => $vc);

    $form->header();
    print $form->parse_html_template('sepa/bank_transfer_created',
                                      {
                                        'id' => $id,
                                        'vc' => $vc,
                                      });
  }

  $main::lxdebug->leave_sub();
}

sub validate_vendors_swiss_export {
  my ($bank_transfers) = @_;

  my $form          = $main::form;
  my $locale        = $main::locale;
  my $myconfig      = \%main::myconfig;

  # determine unique vendor types
  my %unique_vendor_types;
  for my $bt (@$bank_transfers) {
    my $uid = "$bt->{vc_id}_$bt->{type}";

    # if qr-bill get iban from qr-bill data to display in vendor account information,
    # important for manual verification
    my $qr_iban;
    if ($bt->{type} eq 'QRBILL') {
      my $qr_bill_data = SL::Helper::QrBillParser->new($bt->{qrbill_data});
      $qr_iban = $qr_bill_data->{creditor_information}->{iban};
    }

    $unique_vendor_types{$uid} = {
      vc_id => $bt->{vc_id},
      type => $bt->{type},
      qr_iban => $qr_iban,
    } unless defined $unique_vendor_types{$uid};
  }

  # get bank info for unique vendor types
  my $vendors = $form->{vc_bank_info} ?
    { map { $_->{id} => $_ } @{ $form->{vc_bank_info} } } :
    CT->get_bank_info('vc' => 'vendor', 'id' => [ map { $_->{vc_id} } values %unique_vendor_types ]);

  # combine bank info with unique vendor types
  for my $unique_vendor (values %unique_vendor_types) {
    $vendors->{$unique_vendor->{vc_id}}->{type} = $unique_vendor->{type};
    if ($unique_vendor->{type} eq 'QRBILL') {
      $vendors->{$unique_vendor->{vc_id}}->{qr_iban} = $unique_vendor->{qr_iban};
    }
  }

  # validate bank info for unique vendor types
  my $error_message;
  for my $vendor (values %$vendors) {
    next if ($vendor->{type} eq 'QRBILL');
    if ($vendor->{type} eq 'DOMESTIC' && !$vendor->{iban}) {
      $error_message = $locale->text('The bank information must not be empty.');
      last;
    } elsif ($vendor->{type} eq 'SEPA' && (!$vendor->{iban} || !$vendor->{bic})) {
      $error_message = $locale->text('The bank information must not be empty.');
      last;
    }
  }

  return $error_message, $vendors;
}

sub bank_transfer_search {
  $main::lxdebug->enter_sub();

  my $form   = $main::form;
  my $locale = $main::locale;
  my $vc     = $form->{vc} eq 'customer' ? 'customer' : 'vendor';

  $form->{title}    = $vc eq 'customer' ? $::locale->text('List of bank collections') : $locale->text('List of bank transfers');

  setup_sepa_search_transfer_action_bar();

  $form->header();
  print $form->parse_html_template('sepa/bank_transfer_search', { vc => $vc });

  $main::lxdebug->leave_sub();
}


sub bank_transfer_list {
  $main::lxdebug->enter_sub();

  my $form   = $main::form;
  my $locale = $main::locale;
  my $cgi    = $::request->{cgi};
  my $vc     = $form->{vc} eq 'customer' ? 'customer' : 'vendor';

  $form->{title}     = $vc eq 'customer' ? $::locale->text('List of bank collections') : $locale->text('List of bank transfers');

  $form->{sort}    ||= 'id';
  $form->{sortdir}   = '1' if (!defined $form->{sortdir});

  $form->{callback}  = build_std_url('action=bank_transfer_list', 'sort', 'sortdir', 'vc');

  my %filter         = map  +( $_ => $form->{"f_${_}"} ),
                       grep  { $form->{"f_${_}"} }
                             (qw(vc invnumber message_id),
                              map { ("${_}_date_from", "${_}_date_to") }
                                  qw(export requested_execution execution));
  $filter{executed}  = $form->{l_executed} ? 1 : 0 if ($form->{l_executed} != $form->{l_not_executed});
  $filter{closed}    = $form->{l_closed}   ? 1 : 0 if ($form->{l_open}     != $form->{l_closed});

  my $exports        = SL::SEPA->list_exports('filter'    => \%filter,
                                              'sortorder' => $form->{sort},
                                              'sortdir'   => $form->{sortdir},
                                              'vc'        => $vc);

  my $open_available = any { !$_->{closed} } @{ $exports };

  my $report         = SL::ReportGenerator->new(\%main::myconfig, $form);

  my @hidden_vars    = ('vc', grep { m/^[fl]_/ && $form->{$_} } keys %{ $form });

  my $href           = build_std_url('action=bank_transfer_list', @hidden_vars);

  my %column_defs = (
    'selected'    => { 'text' => $cgi->checkbox(-name => 'select_all', -id => 'select_all', -label => ''), },
    'id'          => { 'text' => $locale->text('Number'), },
    'export_date' => { 'text' => $locale->text('Export date'), },
    'employee'    => { 'text' => $locale->text('Employee'), },
    'executed'    => { 'text' => $locale->text('Executed'), },
    'closed'      => { 'text' => $locale->text('Closed'), },
    num_invoices  => { 'text' => $locale->text('Number of invoices'), },
    sum_amounts   => { 'text' => $locale->text('Sum of all amounts'), },
    message_ids   => { 'text' => !$::instance_conf->get_sepa_swiss_xml_export ? $locale->text('SEPA message IDs') : $locale->text('Message IDs'), },
  );

  my @columns = qw(selected id export_date employee executed closed num_invoices sum_amounts message_ids);
  my %column_alignment = map { ($_ => 'right') } qw(num_invoices sum_amounts);

  foreach my $name (qw(id export_date employee executed closed)) {
    my $sortdir                 = $form->{sort} eq $name ? 1 - $form->{sortdir} : $form->{sortdir};
    $column_defs{$name}->{link} = $href . "&sort=$name&sortdir=$sortdir";
  }

  $column_defs{selected}->{visible} = $open_available                                ? 'HTML' : 0;
  $column_defs{executed}->{visible} = $form->{l_executed} && $form->{l_not_executed} ? 1 : 0;
  $column_defs{closed}->{visible}   = $form->{l_closed}   && $form->{l_open}         ? 1 : 0;
  $column_defs{$_}->{align}         = $column_alignment{$_} for keys %column_alignment;

  my @options = ();
  push @options, ($vc eq 'customer' ? $::locale->text('Customer') : $locale->text('Vendor')) . ' : ' . $form->{f_vc} if ($form->{f_vc});
  push @options, $locale->text('Invoice number')                . ' : ' . $form->{f_invnumber}                     if ($form->{f_invnumber});
  push @options, $locale->text('SEPA message ID')               . ' : ' . $form->{f_message_id}                    if (length $form->{f_message_id});
  push @options, $locale->text('Export date from')              . ' : ' . $form->{f_export_date_from}              if ($form->{f_export_date_from});
  push @options, $locale->text('Export date to')                . ' : ' . $form->{f_export_date_to}                if ($form->{f_export_date_to});
  push @options, $locale->text('Requested execution date from') . ' : ' . $form->{f_requested_execution_date_from} if ($form->{f_requested_execution_date_from});
  push @options, $locale->text('Requested execution date to')   . ' : ' . $form->{f_requested_execution_date_to}   if ($form->{f_requested_execution_date_to});
  push @options, $locale->text('Execution date from')           . ' : ' . $form->{f_execution_date_from}           if ($form->{f_execution_date_from});
  push @options, $locale->text('Execution date to')             . ' : ' . $form->{f_execution_date_to}             if ($form->{f_execution_date_to});
  push @options, $form->{l_executed} ? $locale->text('executed') : $locale->text('not yet executed')               if ($form->{l_executed} != $form->{l_not_executed});
  push @options, $form->{l_closed}   ? $locale->text('closed')   : $locale->text('open')                           if ($form->{l_open}     != $form->{l_closed});

  $report->set_options('top_info_text'         => join("\n", @options),
                       'raw_top_info_text'     => $form->parse_html_template('sepa/bank_transfer_list_top'),
                       'raw_bottom_info_text'  => $form->parse_html_template('sepa/bank_transfer_list_bottom', { 'show_buttons' => $open_available, vc => $vc }),
                       'std_column_visibility' => 1,
                       'output_format'         => 'HTML',
                       'title'                 => $form->{title},
                       'attachment_basename'   => $locale->text('banktransfers') . strftime('_%Y%m%d', localtime time),
    );
  $report->set_options_from_form();
  $locale->set_numberformat_wo_thousands_separator(\%::myconfig) if lc($report->{options}->{output_format}) eq 'csv';

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options('bank_transfer_list', @hidden_vars);
  $report->set_sort_indicator($form->{sort}, $form->{sortdir});

  my $edit_url = build_std_url('action=bank_transfer_edit', 'callback');

  foreach my $export (@{ $exports }) {
    my $row = { map { $_ => { 'data' => $export->{$_}, 'align' => $column_alignment{$_} } } keys %{ $export } };

    map { $row->{$_}->{data} = $export->{$_} ? $locale->text('yes') : $locale->text('no') } qw(executed closed);

    $row->{id}->{link} = $edit_url . '&id=' . E($export->{id}) . '&vc=' . E($vc);

    $row->{$_}->{data} = $::form->format_amount(\%::myconfig, $row->{$_}->{data}, 2) for qw(sum_amounts);

    if (!$export->{closed}) {
      $row->{selected}->{raw_data} = $cgi->checkbox(-name => "ids[]", -value => $export->{id}, -label => '');
    }

    $report->add_data($row);
  }

  setup_sepa_list_transfers_action_bar(show_buttons => $open_available, is_vendor => $vc eq 'vendor');

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

sub bank_transfer_edit {
  $main::lxdebug->enter_sub();

  my $form   = $main::form;
  my $locale = $main::locale;
  my $vc     = $form->{vc} eq 'customer' ? 'customer' : 'vendor';

  my @ids    = ();
  if (!$form->{mode} || ($form->{mode} eq 'single')) {
    push @ids, $form->{id};
  } else {
    @ids = @{ $form->{ids} || [] };

    if (!@ids) {
      $form->show_generic_error($locale->text('You have not selected any export.'));
    }
  }

  my $export;

  foreach my $id (@ids) {
    my $curr_export = SL::SEPA->retrieve_export('id' => $id, 'details' => 1, 'vc' => $vc);

    foreach my $item (@{ $curr_export->{items} }) {
      map { $item->{"export_${_}"} = $curr_export->{$_} } grep { !ref $curr_export->{$_} } keys %{ $curr_export };
    }

    if (!$export) {
      $export = $curr_export;
    } else {
      push @{ $export->{items} }, @{ $curr_export->{items} };
    }
  }

  if ($form->{mode} && ($form->{mode} eq 'multi')) {
    $export->{items} = [ grep { !$_->{export_closed} && !$_->{executed} } @{ $export->{items} } ];

    if (!@{ $export->{items} }) {
      $form->show_generic_error($locale->text('All the selected exports have already been closed, or all of their items have already been executed.'));
    }

  } elsif (!$export) {
    $form->error($locale->text('That export does not exist.'));
  }

  my $show_post_payments_button = any { !$_->{export_closed} && !$_->{executed} } @{ $export->{items} };
  my $has_executed              = any { $_->{executed}                          } @{ $export->{items} };

  setup_sepa_edit_transfer_action_bar(
    show_post_payments_button => $show_post_payments_button,
    has_executed              => $has_executed,
  );

  $form->{title}    = !$::instance_conf->get_sepa_swiss_xml_export ?
                        $locale->text('View SEPA export') :
                        $locale->text('View bank transfer');
  $form->header();
  print $form->parse_html_template('sepa/bank_transfer_edit',
                                   { ids                       => \@ids,
                                     export                    => $export,
                                     current_date              => $form->current_date(\%main::myconfig),
                                     show_post_payments_button => $show_post_payments_button,
                                   });

  $main::lxdebug->leave_sub();
}

sub bank_transfer_post_payments {
  $main::lxdebug->enter_sub();

  my $form   = $main::form;
  my $locale = $main::locale;
  my $vc     = $form->{vc} eq 'customer' ? 'customer' : 'vendor';

  my %selected = map { ($_ => 1) } @{ $form->{ids} || [] };
  my @items    = grep { $selected{$_->{id}} } @{ $form->{items} || [] };

  if (!@items) {
    $form->show_generic_error($locale->text('You have not selected any item.'));
  }
  my @export_ids    = uniq map { $_->{sepa_export_id} } @items;
  my %exports       = map { $_ => SL::SEPA->retrieve_export('id' => $_, 'details' => 1, vc => $vc) } @export_ids;
  my @items_to_post = ();

  foreach my $item (@items) {
    my $export = $exports{ $item->{sepa_export_id} };
    next if (!$export || $export->{closed} || $export->{executed});

    push @items_to_post, $item if (none { ($_->{id} == $item->{id}) && $_->{executed} } @{ $export->{items} });
  }

  if (!@items_to_post) {
    $form->show_generic_error($locale->text('All the selected exports have already been closed, or all of their items have already been executed.'));
  }

  if (any { !$_->{execution_date} } @items_to_post) {
    $form->show_generic_error($locale->text('You have to specify an execution date for each antry.'));
  }

  SL::SEPA->post_payment('items' => \@items_to_post, vc => $vc);

  $form->show_generic_information($locale->text('The payments have been posted.'));

  $main::lxdebug->leave_sub();
}

sub bank_transfer_payment_list_as_pdf {
  $main::lxdebug->enter_sub();

  my $form       = $main::form;
  my %myconfig   = %main::myconfig;
  my $locale     = $main::locale;
  my $vc         = $form->{vc} eq 'customer' ? 'customer' : 'vendor';

  my @ids        = @{ $form->{ids} || [] };
  my @export_ids = uniq map { $_->{sepa_export_id} } @{ $form->{items} || [] };

  $form->show_generic_error($locale->text('Multi mode not supported.')) if 1 != scalar @export_ids;

  my $export = SL::SEPA->retrieve_export('id' => $export_ids[0], 'details' => 1, vc => $vc);
  my @items  = ();

  foreach my $id (@ids) {
    my $item = first { $_->{id} == $id } @{ $export->{items} };
    push @items, $item if $item;
  }

  $form->show_generic_error($locale->text('No transfers were executed in this export.')) if 1 > scalar @items;

  my $report         =  SL::ReportGenerator->new(\%main::myconfig, $form);

  my %column_defs    =  (
    'invnumber'      => { 'text' => $locale->text('Invoice'),                                                                  },
    'vc_name'        => { 'text' => $vc eq 'customer' ? $locale->text('Customer')         : $locale->text('Vendor'),           },
    'our_iban'       => { 'text' => $vc eq 'customer' ? $locale->text('Destination IBAN') : $locale->text('Source IBAN'),      },
    'our_bic'        => { 'text' => $vc eq 'customer' ? $locale->text('Destination BIC')  : $locale->text('Source BIC'),       },
    'vc_iban'        => { 'text' => $vc eq 'customer' ? $locale->text('Source IBAN')      : $locale->text('Destination IBAN'), },
    'vc_bic'         => { 'text' => $vc eq 'customer' ? $locale->text('Source BIC')       : $locale->text('Destination BIC'),  },
    'amount'         => { 'text' => $locale->text('Amount'),                                                                   },
    'reference'      => { 'text' => $locale->text('Reference'),                                                                },
    'execution_date' => { 'text' => $locale->text('Execution date'),                                                           },
  );

  map { $column_defs{$_}->{align} = 'right' } qw(amount execution_date);

  my @columns        =  qw(invnumber vc_name our_iban our_bic vc_iban vc_bic amount reference execution_date);

  $report->set_options('std_column_visibility' => 1,
                       'output_format'         => 'PDF',
                       'title'                 =>  $vc eq 'customer' ? $locale->text('Bank collection payment list for export #1', $export->{id}) : $locale->text('Bank transfer payment list for export #1', $export->{id}),
                       'attachment_basename'   => ($vc eq 'customer' ? $locale->text('bank_collection_payment_list_#1', $export->{id}) : $locale->text('bank_transfer_payment_list_#1', $export->{id})) . strftime('_%Y%m%d', localtime time),
    );

  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);

  foreach my $item (@items) {
    my $row                = { map { $_ => { 'data' => $item->{$_} } } @columns };
    $row->{amount}->{data} = $form->format_amount(\%myconfig, $item->{amount}, 2);

    $report->add_data($row);
  }

  $report->generate_with_headers();

  $main::lxdebug->leave_sub();
}

# TODO
sub bank_transfer_download_sepa_xml {
  $main::lxdebug->enter_sub();

  my $form     =  $main::form;
  my $myconfig = \%main::myconfig;
  my $locale   =  $main::locale;
  my $cgi      =  $::request->{cgi};
  my $vc       = $form->{vc} eq 'customer' ? 'customer' : 'vendor';
  my $defaults = SL::DB::Default->get;

  my $swiss_export = $::instance_conf->get_sepa_swiss_xml_export;

  if (!$defaults->company) {
    $form->show_generic_error($locale->text('You have to enter a company name in the client configuration.'));
  }

  if (($vc eq 'customer') && !$defaults->sepa_creditor_id) {
    $form->show_generic_error($locale->text('You have to enter the SEPA creditor ID in the client configuration.'));
  }

  my @ids;
  if ($form->{mode} && ($form->{mode} eq 'multi')) {
     @ids = @{ $form->{ids} || [] };

  } else {
    @ids = ($form->{id});
  }

  if (!@ids) {
    $form->show_generic_error($locale->text('You have not selected any export.'));
  }

  my @items = ();

  foreach my $id (@ids) {
    my $export = SL::SEPA->retrieve_export('id' => $id, 'details' => 1, vc => $vc);
    push @items, grep { !$_->{executed} } @{ $export->{items} } if ($export && !$export->{closed});
  }

  if (!@items) {
    $form->show_generic_error($locale->text('All the selected exports have already been closed, or all of their items have already been executed.'));
  }

  my $message_id = strftime('MSG%Y%m%d%H%M%S', localtime) . sprintf('%06d', $$);

  my $sepa_xml;
  my %sepa_xml_params = (
    'company'     => $defaults->company,
    'creditor_id' => $defaults->sepa_creditor_id,
    'src_charset' => 'UTF-8',
    'message_id'  => $message_id,
    'grouped'     => 1,
    'collection'  => $vc eq 'customer',
  );
  if (!$swiss_export) {
      $sepa_xml = SL::SEPA::XML->new(%sepa_xml_params);
  } else {
      $sepa_xml = SL::SEPA::SwissXML->new(%sepa_xml_params);
  }

  foreach my $item (@items) {
    my $requested_execution_date;
    my $mandator_id;
    if ($item->{requested_execution_date}) {
      my ($yy, $mm, $dd)        = $locale->parse_date($myconfig, $item->{requested_execution_date});
      $requested_execution_date = sprintf '%04d-%02d-%02d', $yy, $mm, $dd;
    }

    if ($vc eq 'customer') {
      my ($yy, $mm, $dd)      = $locale->parse_date($myconfig, $item->{reference_date});
      $item->{reference_date} = sprintf '%04d-%02d-%02d', $yy, $mm, $dd;
      $mandator_id = $item->{mandator_id};
      if ($item->{mandate_date_of_signature}) {
        ($yy, $mm, $dd)                    = $locale->parse_date($myconfig, $item->{mandate_date_of_signature});
        $item->{mandate_date_of_signature} = sprintf '%04d-%02d-%02d', $yy, $mm, $dd;
      }
    }

    my $transaction_data = {
      'src_iban'       => $item->{our_iban},
      'src_bic'        => $item->{our_bic},
      'dst_iban'       => $item->{vc_iban},
      'dst_bic'        => $item->{vc_bic},
      'company'        => $item->{vc_name},
      'company_number' => $item->{vc_number},
      'amount'         => $item->{amount},
      'reference'      => $item->{reference},
      'mandator_id'    => $mandator_id,
      'reference_date' => $item->{reference_date},
      'execution_date' => $requested_execution_date,
      'end_to_end_id'  => $item->{end_to_end_id},
      'date_of_signature' => $item->{mandate_date_of_signature},
    };

    # set data for swiss xml export
    if ($swiss_export) {

      $transaction_data->{currency} = $item->{currency_name};
      $transaction_data->{is_qrbill} = 0;
      $transaction_data->{is_sepa_payment} = 0;

      if ($item->{qrbill_data}) {
        my $qr_obj = SL::Helper::QrBillParser->new($item->{qrbill_data});
        # check if valid qr-bill
        if (!$qr_obj->is_valid) {
          $form->show_generic_error($locale->text('QR bill data invalid.'));
        }
        $transaction_data->{is_qrbill} = 1;

        # set qr reference type
        # setting these according to example pain_001_Example_PT_D_QRR_SCOR.xml
        # 'QRR'
        if ($qr_obj->{payment_reference}->{reference_type} eq 'QRR') {
          $transaction_data->{end_to_end_id} = 'ENDTOENDID-QRR';
        }
        # 'SCOR'
        elsif ($qr_obj->{payment_reference}->{reference_type} eq 'SCOR') {
          $transaction_data->{end_to_end_id} = 'ENDTOENDID-SCOR';
        }
        # 'NON'
        # (using the default end_to_end_id given above)

        # data for remittance information
        # this contains the reference for 'QRR' or 'SCOR'
        $transaction_data->{reference} = $qr_obj->{payment_reference}->{reference};
        # this can be used in any case
        $transaction_data->{unstructured_message} = $qr_obj->{additional_information}->{unstructured_message};

        # set currency and amount
        $transaction_data->{currency} = $qr_obj->{payment_amount_information}->{currency};
        $transaction_data->{amount} = $qr_obj->{payment_amount_information}->{amount};

        # set creditor name and address from qr data
        $transaction_data->{creditor_name} = $qr_obj->{creditor}->{name};
        $transaction_data->{creditor_street_name} = $qr_obj->get_creditor_street_name;
        $transaction_data->{creditor_building_number} = $qr_obj->get_creditor_building_number;
        $transaction_data->{creditor_postal_code} = $qr_obj->get_creditor_post_code;
        $transaction_data->{creditor_town_name} = $qr_obj->get_creditor_town_name;
        $transaction_data->{creditor_country} = $qr_obj->{creditor}->{country};

        # set creditor iban
        $transaction_data->{dst_iban} = $qr_obj->{creditor_information}->{iban};
      } else {
        # if no qr-bill data is given, we want to set the creditor address from the vc data
        # this is not needed for the creditor name as it is set above

        $transaction_data->{has_creditor_address} = 0;

        if ($item->{vc_zipcode} && $item->{vc_city} && $item->{vc_country}) {
          $transaction_data->{has_creditor_address} = 1;

          $transaction_data->{creditor_street_name} = get_street_name_from_address_line($item->{vc_street});
          $transaction_data->{creditor_building_number} = get_building_number_from_address_line($item->{vc_street});

          $transaction_data->{creditor_postal_code} = $item->{vc_zipcode};
          $transaction_data->{creditor_town_name} = $item->{vc_city};
          # use ISO 3166-1 alpha-2 country code
          $transaction_data->{creditor_country} = SL::Helper::ISO3166::map_name_to_alpha_2_code($item->{vc_country});
        }

        # if the Iban does not start with 'CH' or 'LI' we assume it is a SEPA payment
        if ($item->{vc_iban} !~ /^(CH|LI)/) {
          $transaction_data->{is_sepa_payment} = 1;

          # check if currency is EUR
          if ($transaction_data->{currency} ne 'EUR') {
            $form->show_generic_error($locale->text('SEPA payments must be in EUR.'));
          }

          # check if destination BIC is set
          if (!$transaction_data->{dst_bic}) {
            $form->show_generic_error($locale->text('SEPA payments require a destination BIC.'));
          }
          # TODO: set reference (unstructured or SCOR)
          # -> where should the data come from?
        }
      }
    }

    $sepa_xml->add_transaction($transaction_data);
  }

  # Store the message ID used in each of the entries in order to
  # facilitate finding them by looking at bank statements.
  foreach my $id (@ids) {
    SL::DB::SepaExportMessageId->new(
      sepa_export_id => $id,
      message_id     => $message_id,
    )->save;
  }

  my $xml = $sepa_xml->to_xml();

  my $header;
  if ($swiss_export) {
    # I had to use encode for the length here, otherwise the xml output was cut off
    $header = {
      '-type' => 'text/xml; charset=utf-8',
      '-content-disposition' => 'attachment; filename="SWISS_' . $message_id . '.xml' . '"',
      '-content-length' => length Encode::encode('utf-8', $xml),
    };
  } else {
    $header = {
      '-type' => 'application/octet-stream',
      '-content-disposition' => 'attachment; filename="SEPA_' . $message_id . ($vc eq 'customer' ? '.cdd' : '.cct') . '"',
      '-content-length' => length $xml,
    };
  }

  print $cgi->header($header);
  print $xml;

  $main::lxdebug->leave_sub();
}

sub bank_transfer_mark_as_closed {
  $main::lxdebug->enter_sub();

  my $form       = $main::form;
  my $locale     = $main::locale;

  map { SL::SEPA->close_export('id' => $_); } @{ $form->{ids} || [] };

  $form->{title} = $locale->text('Close SEPA exports');
  $form->header();
  $form->show_generic_information($locale->text('The selected exports have been closed.'));

  $main::lxdebug->leave_sub();
}

sub bank_transfer_undo_sepa_xml {
  $main::lxdebug->enter_sub();

  my $form       = $main::form;
  my $locale     = $main::locale;

  map { SL::SEPA->undo_export('id' => $_); } @{ $form->{ids} || [] };

  $form->{title} = $locale->text('Undo SEPA exports');
  $form->header();
  $form->show_generic_information($locale->text('The selected exports have been undone.'));

  $main::lxdebug->leave_sub();
}

sub dispatcher {
  my $form = $main::form;

  foreach my $action (qw(bank_transfer_create bank_transfer_edit bank_transfer_list
                         bank_transfer_post_payments bank_transfer_download_sepa_xml
                         bank_transfer_mark_as_closed_step1 bank_transfer_mark_as_closed_step2
                         bank_transfer_payment_list_as_pdf bank_transfer_undo_sepa_xml)) {
    if ($form->{"action_${action}"}) {
      call_sub($action);
      return;
    }
  }

  $form->error($main::locale->text('No action defined.'));
}

sub setup_sepa_add_transfer_action_bar {
  my (%params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Step 2'),
        submit    => [ '#form', { action => "bank_transfer_create" } ],
        accesskey => 'enter',
        checks    => [ [ 'kivi.check_if_entries_selected', '[name="ids[]"]' ] ],
      ],
    );
  }
}

sub setup_sepa_create_transfer_action_bar {
  my (%params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Create'),
        submit    => [ '#form', { action => "bank_transfer_create" } ],
        accesskey => 'enter',
        tooltip   => $params{is_vendor} ? t8('Create bank transfer') : t8('Create bank collection'),
      ],
      action => [
        t8('Back'),
        call => [ 'kivi.history_back' ],
      ],
    );
  }
}

sub setup_sepa_search_transfer_action_bar {
  my (%params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Search'),
        submit    => [ '#form', { action => 'bank_transfer_list' } ],
        accesskey => 'enter',
      ],
    );
  }
}

sub setup_sepa_list_transfers_action_bar {
  my (%params) = @_;

  return unless $params{show_buttons};

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [ t8('Actions') ],
        action => [
          !$::instance_conf->get_sepa_swiss_xml_export ? t8('SEPA XML download') : t8('Swiss XML download'),
          submit => [ '#form', { action => 'bank_transfer_download_sepa_xml' } ],
          checks => [ [ 'kivi.check_if_entries_selected', '[name="ids[]"]' ] ],
        ],
        action => [
          t8('Post payments'),
          submit => [ '#form', { action => 'bank_transfer_edit' } ],
          checks => [ [ 'kivi.check_if_entries_selected', '[name="ids[]"]' ] ],
        ],
        action => [
          t8('Mark as closed'),
          submit => [ '#form', { action => 'bank_transfer_mark_as_closed' } ],
          checks => [ [ 'kivi.check_if_entries_selected', '[name="ids[]"]' ] ],
          confirm => [ !$::instance_conf->get_sepa_swiss_xml_export ?
                          $params{is_vendor} ? t8('Do you really want to close the selected SEPA exports? No payment will be recorded for bank transfers that haven\'t been marked as executed yet.')
                                             : t8('Do you really want to close the selected SEPA exports? No payment will be recorded for bank collections that haven\'t been marked as executed yet.')
                                             : t8('Do you really want to close the selected Swiss XML exports? No payment will be recorded for bank transfers that haven\'t been marked as executed yet.') ],
        ],
        action => [
          !$::instance_conf->get_sepa_swiss_xml_export ? t8('Undo SEPA exports') : t8('Undo Swiss XML exports'),
          submit => [ '#form', { action => 'bank_transfer_undo_sepa_xml' } ],
          checks => [ [ 'kivi.check_if_entries_selected', '[name="ids[]"]' ] ],
          confirm => [ !$::instance_conf->get_sepa_swiss_xml_export ?
            t8('Do you really want to undo the selected SEPA exports? You have to reassign the export again.') :
            t8('Do you really want to undo the selected Swiss XML exports? You have to reassign the export again.') ],
        ],
      ], # end of combobox "Actions"
    );
  }
}

sub setup_sepa_edit_transfer_action_bar {
  my (%params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Post'),
        submit    => [ '#form', { action => 'bank_transfer_post_payments' } ],
        accesskey => 'enter',
        tooltip   => t8('Post payments for selected invoices'),
        checks    => [ [ 'kivi.check_if_entries_selected', '[name="ids[]"]' ] ],
        disabled  => $params{show_post_payments_button} ? undef : t8('All payments have already been posted.'),
      ],
      action => [
        t8('Payment list'),
        submit    => [ '#form', { action => 'bank_transfer_payment_list_as_pdf' } ],
        accesskey => 'enter',
        tooltip   => t8('Download list of payments as PDF'),
        checks    => [ [ 'kivi.check_if_entries_selected', '[name="ids[]"]' ] ],
        disabled  => $params{show_post_payments_button} ? t8('All payments must be posted before the payment list can be downloaded.') : undef,
      ],
    );
  }
}

1;
