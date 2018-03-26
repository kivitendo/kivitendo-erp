package SL::BackgroundJob::CreatePeriodicInvoices;

use strict;

use parent qw(SL::BackgroundJob::Base);

use Config::Std;
use DateTime::Format::Strptime;
use English qw(-no_match_vars);
use List::MoreUtils qw(uniq);

use SL::DB::AuthUser;
use SL::DB::Default;
use SL::DB::Order;
use SL::DB::Invoice;
use SL::DB::PeriodicInvoice;
use SL::DB::PeriodicInvoicesConfig;
use SL::Helper::CreatePDF qw(create_pdf find_template);
use SL::Mailer;
use SL::Util qw(trim);

sub create_job {
  $_[0]->create_standard_job('0 3 1 * *'); # first day of month at 3:00 am
}

sub run {
  my $self        = shift;
  $self->{db_obj} = shift;

  $self->{job_errors} = [];

  my $configs = SL::DB::Manager::PeriodicInvoicesConfig->get_all(query => [ active => 1 ]);

  foreach my $config (@{ $configs }) {
    my $new_end_date = $config->handle_automatic_extension;
    _log_msg("Periodic invoice configuration ID " . $config->id . " extended through " . $new_end_date->strftime('%d.%m.%Y') . "\n") if $new_end_date;
  }

  my (@new_invoices, @invoices_to_print, @invoices_to_email, @disabled_orders);

  _log_msg("Number of configs: " . scalar(@{ $configs}));

  foreach my $config (@{ $configs }) {
    # A configuration can be set to inactive by
    # $config->handle_automatic_extension. Therefore the check in
    # ...->get_all() does not suffice.
    _log_msg("Config " . $config->id . " active " . $config->active);
    next unless $config->active;

    my @dates = _calculate_dates($config);

    _log_msg("Dates: " . join(' ', map { $_->to_lxoffice } @dates));

    foreach my $date (@dates) {
      my $data = $self->_create_periodic_invoice($config, $date);
      next unless $data;

      _log_msg("Invoice " . $data->{invoice}->invnumber . " posted for config ID " . $config->id . ", period start date " . $::locale->format_date(\%::myconfig, $date) . "\n");

      push @new_invoices,      $data;
      push @invoices_to_print, $data if $config->print;
      push @invoices_to_email, $data if $config->send_email;

      my $inactive_ordnumber = $config->disable_one_time_config;
      if ($inactive_ordnumber) {
        # disable one time configs and skip eventual invoices
        _log_msg("Order " . $inactive_ordnumber . " deavtivated \n");
        push @disabled_orders, $inactive_ordnumber;
        last;
      }
    }
  }

  foreach my $inv ( @invoices_to_print ) { $self->_print_invoice($inv); }
  foreach my $inv ( @invoices_to_email ) { $self->_email_invoice($inv); }

  $self->_send_summary_email(
    [ map { $_->{invoice} } @new_invoices      ],
    [ map { $_->{invoice} } @invoices_to_print ],
    [ map { $_->{invoice} } @invoices_to_email ],
                             \@disabled_orders  ,
  );

  if (@{ $self->{job_errors} }) {
    my $msg = join "\n", @{ $self->{job_errors} };
    _log_msg("Errors: $msg");
    die $msg;
  }

  return 1;
}

sub _log_msg {
  my $message  = join('', 'SL::BackgroundJob::CreatePeriodicInvoices: ', @_);
  $message    .= "\n" unless $message =~ m/\n$/;
  $::lxdebug->message(LXDebug::DEBUG1(), $message);
}

sub _generate_time_period_variables {
  my $config            = shift;
  my $period_start_date = shift;
  my $period_end_date   = $period_start_date->clone->add(months => $config->get_billing_period_length)->subtract(days => 1);

  my @month_names       = ('',
                           $::locale->text('January'), $::locale->text('February'), $::locale->text('March'),     $::locale->text('April'),   $::locale->text('May'),      $::locale->text('June'),
                           $::locale->text('July'),    $::locale->text('August'),   $::locale->text('September'), $::locale->text('October'), $::locale->text('November'), $::locale->text('December'));

  my $vars = {
    current_quarter     => [ $period_start_date->clone->truncate(to => 'month'),                        sub { $_[0]->quarter } ],
    previous_quarter    => [ $period_start_date->clone->truncate(to => 'month')->subtract(months => 3), sub { $_[0]->quarter } ],
    next_quarter        => [ $period_start_date->clone->truncate(to => 'month')->add(     months => 3), sub { $_[0]->quarter } ],

    current_month       => [ $period_start_date->clone->truncate(to => 'month'),                        sub { $_[0]->month } ],
    previous_month      => [ $period_start_date->clone->truncate(to => 'month')->subtract(months => 1), sub { $_[0]->month } ],
    next_month          => [ $period_start_date->clone->truncate(to => 'month')->add(     months => 1), sub { $_[0]->month } ],

    current_month_long  => [ $period_start_date->clone->truncate(to => 'month'),                        sub { $month_names[ $_[0]->month ] } ],
    previous_month_long => [ $period_start_date->clone->truncate(to => 'month')->subtract(months => 1), sub { $month_names[ $_[0]->month ] } ],
    next_month_long     => [ $period_start_date->clone->truncate(to => 'month')->add(     months => 1), sub { $month_names[ $_[0]->month ] } ],

    current_year        => [ $period_start_date->clone->truncate(to => 'year'),                         sub { $_[0]->year } ],
    previous_year       => [ $period_start_date->clone->truncate(to => 'year')->subtract(years => 1),   sub { $_[0]->year } ],
    next_year           => [ $period_start_date->clone->truncate(to => 'year')->add(     years => 1),   sub { $_[0]->year } ],

    period_start_date   => [ $period_start_date->clone, sub { $::locale->format_date(\%::myconfig, $_[0]) } ],
    period_end_date     => [ $period_end_date,          sub { $::locale->format_date(\%::myconfig, $_[0]) } ],
  };

  return $vars;
}

sub _replace_vars {
  my (%params) = @_;
  my $sub      = $params{attribute};
  my $str      = $params{object}->$sub // '';
  my $sub_fmt  = lc($params{attribute_format} // 'text');

  my ($start_tag, $end_tag) = $sub_fmt eq 'html' ? ('&lt;%', '%&gt;') : ('<%', '%>');

  $str =~ s{ ${start_tag} ([a-z0-9_]+) ( \s+ format \s*=\s* (.*?) \s* )? ${end_tag} }{
    my ($key, $format) = ($1, $3);
    $key               = $::locale->unquote_special_chars('html', $key) if $sub_fmt eq 'html';
    my $new_value;

    if (!$params{vars}->{$key}) {
      $new_value = '';

    } elsif ($format) {
      $format    = $::locale->unquote_special_chars('html', $format) if $sub_fmt eq 'html';

      $new_value = DateTime::Format::Strptime->new(
        pattern     => $format,
        locale      => 'de_DE',
        time_zone   => 'local',
      )->format_datetime($params{vars}->{$key}->[0]);

    } else {
      $new_value = $params{vars}->{$1}->[1]->($params{vars}->{$1}->[0]);
    }

    $new_value = $::locale->quote_special_chars('html', $new_value) if $sub_fmt eq 'html';

    $new_value;

  }eigx;

  $params{object}->$sub($str);
}

sub _adjust_sellprices_for_period_lengths {
  my (%params) = @_;

  my $billing_len     = $params{config}->get_billing_period_length;
  my $order_value_len = $params{config}->get_order_value_period_length;

  return if $billing_len == $order_value_len;

  my $is_last_invoice_in_cycle = $params{config}->is_last_bill_date_in_order_value_cycle(date => $params{period_start_date});

  _log_msg("_adjust_sellprices_for_period_lengths: period_start_date $params{period_start_date} is_last_invoice_in_cycle $is_last_invoice_in_cycle billing_len $billing_len order_value_len $order_value_len");

  if ($order_value_len < $billing_len) {
    my $num_orders_per_invoice = $billing_len / $order_value_len;

    $_->sellprice($_->sellprice * $num_orders_per_invoice) for @{ $params{invoice}->items };

    return;
  }

  my $num_invoices_in_cycle = $order_value_len / $billing_len;

  foreach my $item (@{ $params{invoice}->items }) {
    my $sellprice_one_invoice = $::form->round_amount($item->sellprice * $billing_len / $order_value_len, 2);

    if ($is_last_invoice_in_cycle) {
      $item->sellprice($item->sellprice - ($num_invoices_in_cycle - 1) * $sellprice_one_invoice);

    } else {
      $item->sellprice($sellprice_one_invoice);
    }
  }
}

sub _create_periodic_invoice {
  my $self              = shift;
  my $config            = shift;
  my $period_start_date = shift;

  my $time_period_vars  = _generate_time_period_variables($config, $period_start_date);

  my $invdate           = DateTime->today_local;

  my $order   = $config->order;
  my $invoice;
  if (!$self->{db_obj}->db->with_transaction(sub {
    1;                          # make Emacs happy

    $invoice = SL::DB::Invoice->new_from($order);

    my $intnotes  = $invoice->intnotes ? $invoice->intnotes . "\n\n" : '';
    $intnotes    .= "Automatisch am " . $invdate->to_lxoffice . " erzeugte Rechnung";

    $invoice->assign_attributes(deliverydate => $period_start_date,
                                intnotes     => $intnotes,
                                employee     => $order->employee, # new_from sets employee to import user
                                direct_debit => $config->direct_debit,
                               );

    _replace_vars(object => $invoice, vars => $time_period_vars, attribute => $_, attribute_format => ($_ eq 'notes' ? 'html' : 'text')) for qw(notes intnotes transaction_description);

    foreach my $item (@{ $invoice->items }) {
      _replace_vars(object => $item, vars => $time_period_vars, attribute => $_, attribute_format => ($_ eq 'longdescription' ? 'html' : 'text')) for qw(description longdescription);
    }

    _adjust_sellprices_for_period_lengths(invoice => $invoice, config => $config, period_start_date => $period_start_date);

    $invoice->post(ar_id => $config->ar_chart_id) || die;

    $order->link_to_record($invoice);

    foreach my $item (@{ $invoice->items }) {
      foreach (qw(orderitems)) {    # expand if needed (delivery_order_items)
          if ($item->{"converted_from_${_}_id"}) {
            die unless $item->{id};
            RecordLinks->create_links('mode'       => 'ids',
                                      'from_table' => $_,
                                      'from_ids'   => $item->{"converted_from_${_}_id"},
                                      'to_table'   => 'invoice',
                                      'to_id'      => $item->{id},
            ) || die;
            delete $item->{"converted_from_${_}_id"};
         }
      }
    }

    SL::DB::PeriodicInvoice->new(config_id         => $config->id,
                                 ar_id             => $invoice->id,
                                 period_start_date => $period_start_date)
      ->save;

    _log_msg("_create_invoice created for period start date $period_start_date id " . $invoice->id . " number " . $invoice->invnumber . " netamount " . $invoice->netamount . " amount " . $invoice->amount);

    # die $invoice->transaction_description;

    1;
  })) {
    $::lxdebug->message(LXDebug->WARN(), "_create_invoice failed: " . join("\n", (split(/\n/, $self->{db_obj}->db->error))[0..2]));
    return undef;
  }

  return {
    config            => $config,
    period_start_date => $period_start_date,
    invoice           => $invoice,
    time_period_vars  => $time_period_vars,
  };
}

sub _calculate_dates {
  my ($config) = @_;
  return $config->calculate_invoice_dates(end_date => DateTime->today_local);
}

sub _send_summary_email {
  my ($self, $posted_invoices, $printed_invoices, $emailed_invoices,
      $disabled_orders) = @_;
  my %config = %::lx_office_conf;

  return if !$config{periodic_invoices} || !$config{periodic_invoices}->{send_email_to} || !scalar @{ $posted_invoices };

  my $user  = SL::DB::Manager::AuthUser->find_by(login => $config{periodic_invoices}->{send_email_to});
  my $email = $user ? $user->get_config_value('email') : undef;

  return unless $email;

  my $template = Template->new({ 'INTERPOLATE' => 0,
                                 'EVAL_PERL'   => 0,
                                 'ABSOLUTE'    => 1,
                                 'CACHE_SIZE'  => 0,
                               });

  return unless $template;

  my $email_template = $config{periodic_invoices}->{email_template};
  my $filename       = $email_template || ( (SL::DB::Default->get->templates || "templates/webpages") . "/oe/periodic_invoices_email.txt" );
  my %params         = ( POSTED_INVOICES  => $posted_invoices,
                         PRINTED_INVOICES => $printed_invoices,
                         EMAILED_INVOICES => $emailed_invoices,
                         DISABLED_ORDERS  => $disabled_orders );

  my $output;
  $template->process($filename, \%params, \$output);

  my $mail              = Mailer->new;
  $mail->{from}         = $config{periodic_invoices}->{email_from};
  $mail->{to}           = $email;
  $mail->{subject}      = $config{periodic_invoices}->{email_subject};
  $mail->{content_type} = $filename =~ m/.html$/ ? 'text/html' : 'text/plain';
  $mail->{message}      = $output;

  $mail->send;
}

sub _print_invoice {
  my ($self, $data) = @_;

  my $invoice       = $data->{invoice};
  my $config        = $data->{config};

  return unless $config->print && $config->printer_id && $config->printer->printer_command;

  my $form = Form->new;
  $invoice->flatten_to_form($form, format_amounts => 1);

  $form->{printer_code} = $config->printer->template_code;
  $form->{copies}       = $config->copies;
  $form->{formname}     = $form->{type};
  $form->{format}       = 'pdf';
  $form->{media}        = 'printer';
  $form->{OUT}          = $config->printer->printer_command;
  $form->{OUT_MODE}     = '|-';

  $form->{TEMPLATE_DRIVER_OPTIONS} = { };
  $form->{TEMPLATE_DRIVER_OPTIONS}->{variable_content_types} = $form->get_variable_content_types();

  $form->prepare_for_printing;

  $form->throw_on_error(sub {
    eval {
      $form->parse_template(\%::myconfig);
      1;
    } or do {
      push @{ $self->{job_errors} }, $EVAL_ERROR->getMessage;
    };
  });
}

sub _email_invoice {
  my ($self, $data) = @_;

  $data->{config}->load;

  return unless $data->{config}->send_email;

  my @recipients =
    uniq
    map  { lc       }
    grep { $_       }
    map  { trim($_) }
    (split(m{,}, $data->{config}->email_recipient_address),
     $data->{config}->email_recipient_contact ? ($data->{config}->email_recipient_contact->cp_email) : ());

  return unless @recipients;

  my %create_params = (
    template               => $self->find_template(name => 'invoice'),
    variables              => Form->new(''),
    return                 => 'file_name',
    variable_content_types => {
      longdescription => 'html',
      partnotes       => 'html',
      notes           => 'html',
    },
  );

  $data->{invoice}->flatten_to_form($create_params{variables}, format_amounts => 1);
  $create_params{variables}->prepare_for_printing;

  my $pdf_file_name;

  eval {
    $pdf_file_name = $self->create_pdf(%create_params);

    for (qw(email_subject email_body)) {
      _replace_vars(
        object           => $data->{config},
        vars             => $data->{time_period_vars},
        attribute        => $_,
        attribute_format => 'text'
      );
    }

    my $global_bcc = SL::DB::Default->get->global_bcc;

    for my $recipient (@recipients) {
      my $mail             = Mailer->new;
      $mail->{record_id}   = $data->{invoice}->id,
      $mail->{record_type} = 'invoice',
      $mail->{from}        = $data->{config}->email_sender || $::lx_office_conf{periodic_invoices}->{email_from};
      $mail->{to}          = $recipient;
      $mail->{bcc}         = $global_bcc;
      $mail->{subject}     = $data->{config}->email_subject;
      $mail->{message}     = $data->{config}->email_body;
      $mail->{attachments} = [{
        path     => $pdf_file_name,
        name     => sprintf('%s %s.pdf', $::locale->text('Invoice'), $data->{invoice}->invnumber),
      }];

      my $error        = $mail->send;

      push @{ $self->{job_errors} }, $error if $error;
    }

    1;

  } or do {
    push @{ $self->{job_errors} }, $EVAL_ERROR;
  };

  unlink $pdf_file_name if $pdf_file_name;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::BackgroundJob::CleanBackgroundJobHistory - Create periodic
invoices for orders

=head1 SYNOPSIS

Iterate over all periodic invoice configurations, extend them if
applicable, calculate the dates for which invoices have to be posted
and post those invoices by converting the order into an invoice for
each date.

=head1 TOTO

=over 4

=item *

Strings like month names are hardcoded to German in this file.

=back

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
