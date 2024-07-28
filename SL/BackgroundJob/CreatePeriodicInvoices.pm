package SL::BackgroundJob::CreatePeriodicInvoices;

use strict;

use parent qw(SL::BackgroundJob::Base);

use Config::Std;
use DateTime::Format::Strptime;
use English qw(-no_match_vars);
use List::MoreUtils qw(uniq);
use Params::Validate qw(:all);

use SL::Common;
use SL::DB::AuthUser;
use SL::DB::Default;
use SL::DB::Order;
use SL::DB::Invoice;
use SL::DB::PeriodicInvoice;
use SL::DB::PeriodicInvoicesConfig;
use SL::File;
use SL::Helper::CreatePDF qw(create_pdf find_template);
use SL::Mailer;
use SL::Util qw(trim);
use SL::System::Process;
use SL::Locale::String qw(t8);

sub create_job {
  $_[0]->create_standard_job('0 3 1 * *'); # first day of month at 3:00 am
}

sub run {
  my $self        = shift;
  $self->{db_obj} = shift;

  $self->{$_} = [] for qw(job_errors posted_invoices printed_invoices printed_failed emailed_invoices emailed_failed disabled_orders);

  if (!$self->{db_obj}->db->with_transaction(sub {
    1;                          # make Emacs happy

    my $configs = SL::DB::Manager::PeriodicInvoicesConfig->get_all(query => [ active => 1 ]);

    foreach my $config (@{ $configs }) {
      $config->handle_automatic_extension();
    }

    my (@invoices_to_print, @invoices_to_email);

    _log_msg("Number of configs: " . scalar(@{ $configs}));

    foreach my $config (@{ $configs }) {
      my $open_orders = $config->get_open_orders_for_period();
      _log_msg("Dates: " . join(' ', map { $_->reqdate->to_lxoffice } @$open_orders));

      foreach my $order (@$open_orders) {
        my $data = $self->_create_periodic_invoice(order => $order);
        my $invoice = $data->{invoice};
        next unless $invoice;

        _log_msg("Invoice " . $invoice->invnumber . " posted for config ID " . $config->id . ", period start date " . $::locale->format_date(\%::myconfig, $invoice->deliverydate) . "\n");

        push @{ $self->{posted_invoices} }, $invoice;
        push @invoices_to_print, $data if $config->print;
        push @invoices_to_email, $data if $config->send_email;

        my $inactive_ordnumber = $config->disable_one_time_config;
        if ($inactive_ordnumber) {
          # disable one time configs and skip eventual invoices
          _log_msg("Order " . $inactive_ordnumber . " deavtivated \n");
          push @{ $self->{disabled_orders} }, $inactive_ordnumber;
          last;
        }
      }
    }

    foreach my $inv_data ( @invoices_to_print ) { $self->_print_invoice($inv_data); }
    foreach my $inv_data ( @invoices_to_email ) { $self->_email_invoice($inv_data); }

    $self->_send_summary_email;

      1;
    })) {
      $::lxdebug->message(LXDebug->WARN(), "_create_invoice failed: " . join("\n", (split(/\n/, $self->{db_obj}->db->error))[0..2]));
      return undef;
    }

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

  my $period_length   = $config->get_order_value_period_length || $config->get_billing_period_length || 1;
  my $period_end_date = $period_start_date->clone->add(months => $period_length)->subtract(days => 1);

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
  my @invoice_keys          = $params{invoice} ? (map { $_->name } $params{invoice}->meta->columns) : ();
  my $key_name_re           = join '|', map { quotemeta } (@invoice_keys, keys %{ $params{vars} });

  $str =~ s{ ${start_tag} ($key_name_re) ( \s+ format \s*=\s* (.*?) \s* )? ${end_tag} }{
    my ($key, $format) = ($1, $3);
    $key               = $::locale->unquote_special_chars('html', $key) if $sub_fmt eq 'html';
    my $new_value;

    if ($params{vars}->{$key} && $format) {
      $format    = $::locale->unquote_special_chars('html', $format) if $sub_fmt eq 'html';

      $new_value = DateTime::Format::Strptime->new(
        pattern     => $format,
        locale      => 'de_DE',
        time_zone   => 'local',
      )->format_datetime($params{vars}->{$key}->[0]);

    } elsif ($params{vars}->{$key}) {
      $new_value = $params{vars}->{$1}->[1]->($params{vars}->{$1}->[0]);

    } elsif ($params{invoice} && $params{invoice}->can($key)) {
      $new_value = $params{invoice}->$key;
    }

    $new_value //= '';
    $new_value   = $::locale->quote_special_chars('html', $new_value) if $sub_fmt eq 'html';

    $new_value;

  }eigx;

  $params{object}->$sub($str);
}

sub _create_periodic_invoice {
  my $self  = shift;

  my %params = validate(@_, {
    order => { isa => 'SL::DB::Order' },
  });
  my $order = $params{order};

  my $period_start_date = $order->reqdate;
  my $config            = $order->periodic_invoices_config;
  my $time_period_vars  = _generate_time_period_variables($config, $period_start_date);

  my $invoice;
  if (!$self->{db_obj}->db->with_transaction(sub {
    1;                          # make Emacs happy

    $invoice = SL::DB::Invoice->new_from($order);

    my $intnotes  = $invoice->intnotes ? $invoice->intnotes . "\n\n" : '';
    $intnotes    .= t8("Automatic created invoice on #1.", DateTime->today_local->to_lxoffice);

    $invoice->assign_attributes(
      intnotes     => $intnotes,
      employee     => $order->employee, # new_from sets employee to import user
      direct_debit => $config->direct_debit,
    );

    _replace_vars(object => $invoice, vars => $time_period_vars, attribute => $_, attribute_format => ($_ eq 'notes' ? 'html' : 'text')) for qw(notes intnotes transaction_description);

    foreach my $item (@{ $invoice->items }) {
      _replace_vars(object => $item, vars => $time_period_vars, attribute => $_, attribute_format => ($_ eq 'longdescription' ? 'html' : 'text')) for qw(description longdescription);
    }

    $invoice->post(ar_id => $config->ar_chart_id) || die;

    foreach my $item (
      grep { $_->periodic_invoice_items_config
        && ($_->periodic_invoice_items_config->periodicity eq 'o')
        && !$_->periodic_invoice_items_config->once_invoice_id }
      @{ $order->orderitems }
    ) {
      $item->periodic_invoice_items_config->update_attributes(once_invoice_id => $invoice->id);
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
    invoice           => $invoice,
    time_period_vars  => $time_period_vars,
  };
}

sub _send_summary_email {
  my ($self) = @_;
  my %config = %::lx_office_conf;

  return if !$config{periodic_invoices} || !$config{periodic_invoices}->{send_email_to} || !scalar @{ $self->{posted_invoices} };

  return if $config{periodic_invoices}->{send_for_errors_only} && !@{ $self->{printed_failed} } && !@{ $self->{emailed_failed} };

  my $email = $config{periodic_invoices}->{send_email_to};
  if ($email !~ m{\@}) {
    my $user = SL::DB::Manager::AuthUser->find_by(login => $email);
    $email   = $user ? $user->get_config_value('email') : undef;
  }

  _log_msg("_send_summary_email: about to send to '" . ($email || '') . "'");

  return unless $email;

  my $template = Template->new({ 'INTERPOLATE' => 0,
                                 'EVAL_PERL'   => 0,
                                 'ABSOLUTE'    => 1,
                                 'CACHE_SIZE'  => 0,
                               });

  return unless $template;

  my $email_template = $config{periodic_invoices}->{email_template};
  my $filename       = $email_template || ( (SL::DB::Default->get->templates || "templates/webpages") . "/oe/periodic_invoices_email.txt" );
  my %params         = map { (uc($_) => $self->{$_}) } qw(posted_invoices printed_invoices printed_failed emailed_invoices emailed_failed disabled_orders);

  my $output;
  $template->process($filename, \%params, \$output) || die $template->error;

  my $mail              = Mailer->new;
  $mail->{from}         = $config{periodic_invoices}->{email_from};
  $mail->{to}           = $email;
  $mail->{subject}      = $config{periodic_invoices}->{email_subject};
  $mail->{content_type} = $filename =~ m/.html$/ ? 'text/html' : 'text/plain';
  $mail->{message}      = $output;

  $mail->send;
}

sub _store_pdf_in_webdav {
  my ($self, $pdf_file_name, $invoice) = @_;

  return unless $::instance_conf->get_webdav_documents;

  my $form = Form->new('');

  $form->{cwd}              = SL::System::Process->exe_dir;
  $form->{tmpdir}           = ($pdf_file_name =~ m{(.+)/})[0];
  $form->{tmpfile}          = ($pdf_file_name =~ m{.+/(.+)})[0];
  $form->{format}           = 'pdf';
  $form->{formname}         = 'invoice';
  $form->{type}             = 'invoice';
  $form->{vc}               = 'customer';
  $form->{invnumber}        = $invoice->invnumber;
  $form->{recipient_locale} = $invoice->language ? $invoice->language->template_code : '';

  Common::copy_file_to_webdav_folder($form);
}

sub _store_pdf_in_filemanagement {
  my ($self, $pdf_file, $invoice) = @_;

  return unless $::instance_conf->get_doc_storage;

  # create a form for generate_attachment_filename
  my $form = Form->new('');
  $form->{invnumber} = $invoice->invnumber;
  $form->{type}      = 'invoice';
  $form->{format}    = 'pdf';
  $form->{formname}  = 'invoice';
  $form->{language}  = '_' . $invoice->language->template_code if $invoice->language;
  my $doc_name       = $form->generate_attachment_filename();

  SL::File->save(object_id   => $invoice->id,
                 object_type => 'invoice',
                 mime_type   => 'application/pdf',
                 source      => 'created',
                 file_type   => 'document',
                 file_name   => $doc_name,
                 file_path   => $pdf_file);
}

sub _print_invoice {
  my $self = shift;

    my %params = validate_with(
    params => \@_,
    spec   => {
      invoice => { isa => 'SL::DB::Invoice' },
      config  => { isa => 'SL::DB::PeriodicInvoicesConfig' },
    },
    allow_extra => 1,
  );

  my $invoice = $params{invoice};
  my $config  = $params{config};

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
      push @{ $self->{printed_invoices} }, $invoice;
      1;
    } or do {
      push @{ $self->{job_errors} }, $EVAL_ERROR->error;
      push @{ $self->{printed_failed} }, [ $invoice, $EVAL_ERROR->error ];
    };
  });
}

sub _email_invoice {
  my $self = shift;

  my %params = validate_with(
    params => \@_,
    spec   => {
      invoice => { isa => 'SL::DB::Invoice' },
      config  => { isa => 'SL::DB::PeriodicInvoicesConfig' },
      time_period_vars => { type => HASHREF },
    },
    allow_extra => 1,
  );

  my $invoice = $params{invoice};
  my $config  = $params{config};
  my $time_period_vars = $params{time_period_vars};

  my @recipients =
    uniq
    map  { lc       }
    grep { $_       }
    map  { trim($_) }
    (split(m{,}, $config->email_recipient_address),
     $config->email_recipient_contact   ? ($config->email_recipient_contact->cp_email) : (),
     $invoice->{customer}->invoice_mail ? ($invoice->{customer}->invoice_mail) : ()
    );

  return unless @recipients;

  my $language      = $invoice->language ? $invoice->language->template_code : undef;
  my %create_params = (
    template               => scalar($self->find_template(name => 'invoice', language => $language)),
    variables              => Form->new(''),
    return                 => 'file_name',
    record                 => $invoice,
    variable_content_types => {
      longdescription => 'html',
      partnotes       => 'html',
      notes           => 'html',
      $::form->get_variable_content_types_for_cvars,
    },
  );

  $invoice->flatten_to_form($create_params{variables}, format_amounts => 1);
  $create_params{variables}->prepare_for_printing;

  my $pdf_file_name;
  my $label = $language && Locale::is_supported($language) ? Locale->new($language)->text('Invoice') : $::locale->text('Invoice');

  eval {
    $pdf_file_name = $self->create_pdf(%create_params);

    $self->_store_pdf_in_webdav        ($pdf_file_name, $invoice);
    $self->_store_pdf_in_filemanagement($pdf_file_name, $invoice);

    for (qw(email_subject email_body)) {
      _replace_vars(
        object           => $config,
        invoice          => $invoice,
        vars             => $time_period_vars,
        attribute        => $_,
        attribute_format => ($_ eq 'email_body' ? 'html' : 'text')
      );
    }

    my $global_bcc = SL::DB::Default->get->global_bcc;
    my $overall_error;

    for my $recipient (@recipients) {
      my $mail             = Mailer->new;
      $mail->{record_id}   = $invoice->id,
      $mail->{record_type} = 'invoice',
      $mail->{from}        = $config->email_sender || $::lx_office_conf{periodic_invoices}->{email_from};
      $mail->{to}          = $recipient;
      $mail->{bcc}         = $global_bcc;
      $mail->{subject}     = $config->email_subject;
      $mail->{message}     = $config->email_body;
      $mail->{message}    .= SL::DB::Default->get->signature;
      $mail->{content_type} = 'text/html';
      $mail->{attachments} = [{
        path     => $pdf_file_name,
        name     => sprintf('%s %s.pdf', $label, $invoice->invnumber),
      }];

      my $error        = $mail->send;

      if ($error) {
        push @{ $self->{job_errors} }, $error;
        push @{ $self->{emailed_failed} }, [ $invoice, $error ];
        $overall_error = 1;
      }
    }

    push @{ $self->{emailed_invoices} }, $invoice unless $overall_error;

    1;

  } or do {
    push @{ $self->{job_errors} }, $EVAL_ERROR;
    push @{ $self->{emailed_failed} }, [ $invoice, $EVAL_ERROR ];
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

Iterate over all periodic invoice configurations, extend the end date if
applicable, get all open orders from the

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
