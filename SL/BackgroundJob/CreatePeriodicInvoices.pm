package SL::BackgroundJob::CreatePeriodicInvoices;

use strict;

use parent qw(SL::BackgroundJob::Base);

use Config::Std;
use English qw(-no_match_vars);

use SL::DB::AuthUser;
use SL::DB::Default;
use SL::DB::Order;
use SL::DB::Invoice;
use SL::DB::PeriodicInvoice;
use SL::DB::PeriodicInvoicesConfig;
use SL::Mailer;

sub create_job {
  $_[0]->create_standard_job('0 3 1 * *'); # first day of month at 3:00 am
}

sub run {
  my $self        = shift;
  $self->{db_obj} = shift;

  my $configs = SL::DB::Manager::PeriodicInvoicesConfig->get_all(query => [ active => 1 ]);

  foreach my $config (@{ $configs }) {
    my $new_end_date = $config->handle_automatic_extension;
    _log_msg("Periodic invoice configuration ID " . $config->id . " extended through " . $new_end_date->strftime('%d.%m.%Y') . "\n") if $new_end_date;
  }

  my (@new_invoices, @invoices_to_print);

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
      my $invoice = $self->_create_periodic_invoice($config, $date);
      next unless $invoice;

      _log_msg("Invoice " . $invoice->invnumber . " posted for config ID " . $config->id . ", period start date " . $::locale->format_date(\%::myconfig, $date) . "\n");
      push @new_invoices,      $invoice;
      push @invoices_to_print, [ $invoice, $config ] if $config->print;

      # last;
    }
  }

  map { _print_invoice(@{ $_ }) } @invoices_to_print;

  _send_email(\@new_invoices, [ map { $_->[0] } @invoices_to_print ]) if @new_invoices;

  return 1;
}

sub _log_msg {
  my $message  = join('', @_);
  $message    .= "\n" unless $message =~ m/\n$/;
  $::lxdebug->message(LXDebug::DEBUG1(), $message);
}

sub _generate_time_period_variables {
  my $config            = shift;
  my $period_start_date = shift;
  my $period_end_date   = $period_start_date->clone->truncate(to => 'month')->add(months => $config->get_period_length)->subtract(days => 1);

  my @month_names       = ('',
                           $::locale->text('January'), $::locale->text('February'), $::locale->text('March'),     $::locale->text('April'),   $::locale->text('May'),      $::locale->text('June'),
                           $::locale->text('July'),    $::locale->text('August'),   $::locale->text('September'), $::locale->text('October'), $::locale->text('November'), $::locale->text('December'));

  my $vars = { current_quarter     => $period_start_date->quarter,
               previous_quarter    => $period_start_date->clone->subtract(months => 3)->quarter,
               next_quarter        => $period_start_date->clone->add(     months => 3)->quarter,

               current_month       => $period_start_date->month,
               previous_month      => $period_start_date->clone->subtract(months => 1)->month,
               next_month          => $period_start_date->clone->add(     months => 1)->month,

               current_year        => $period_start_date->year,
               previous_year       => $period_start_date->year - 1,
               next_year           => $period_start_date->year + 1,

               period_start_date   => $::locale->format_date(\%::myconfig, $period_start_date),
               period_end_date     => $::locale->format_date(\%::myconfig, $period_end_date),
             };

  map { $vars->{"${_}_month_long"} = $month_names[ $vars->{"${_}_month"} ] } qw(current previous next);

  return $vars;
}

sub _replace_vars {
  my $object = shift;
  my $vars   = shift;
  my $sub    = shift;
  my $str    = $object->$sub;

  my ($key, $value);
  $str =~ s|<\%${key}\%>|$value|g while ($key, $value) = each %{ $vars };
  $object->$sub($str);
}

sub _create_periodic_invoice {
  my $self              = shift;
  my $config            = shift;
  my $period_start_date = shift;

  my $time_period_vars  = _generate_time_period_variables($config, $period_start_date);

  my $invdate           = DateTime->today_local;

  my $order   = $config->order;
  my $invoice;
  if (!$self->{db_obj}->db->do_transaction(sub {
    1;                          # make Emacs happy

    $invoice = SL::DB::Invoice->new_from($order);

    my $intnotes  = $invoice->intnotes ? $invoice->intnotes . "\n\n" : '';
    $intnotes    .= "Automatisch am " . $invdate->to_lxoffice . " erzeugte Rechnung";

    $invoice->assign_attributes(deliverydate => $period_start_date,
                                intnotes     => $intnotes,
                               );

    map { _replace_vars($invoice, $time_period_vars, $_) } qw(notes intnotes transaction_description);

    foreach my $item (@{ $invoice->items }) {
      map { _replace_vars($item, $time_period_vars, $_) } qw(description longdescription);
    }

    $invoice->post(ar_id => $config->ar_chart_id) || die;

    $order->link_to_record($invoice);

    SL::DB::PeriodicInvoice->new(config_id         => $config->id,
                                 ar_id             => $invoice->id,
                                 period_start_date => $period_start_date)
      ->save;

    # die $invoice->transaction_description;
  })) {
    $::lxdebug->message(LXDebug->WARN(), "_create_invoice failed: " . join("\n", (split(/\n/, $self->{db_obj}->db->error))[0..2]));
    return undef;
  }

  return $invoice;
}

sub _calculate_dates {
  my $config     = shift;

  my $cur_date   = $config->start_date;
  my $start_date = $config->get_previous_invoice_date || DateTime->new(year => 1970, month => 1, day => 1);
  my $end_date   = $config->end_date                  || DateTime->new(year => 2100, month => 1, day => 1);
  my $tomorrow   = DateTime->today_local->add(days => 1);
  my $period_len = $config->get_period_length;

  $end_date      = $tomorrow if $end_date > $tomorrow;

  my @dates;

  while (1) {
    last if $cur_date >= $end_date;

    push @dates, $cur_date->clone if $cur_date > $start_date;

    $cur_date->add(months => $period_len);
  }

  return @dates;
}

sub _send_email {
  my ($posted_invoices, $printed_invoices) = @_;

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
  my $filename       = $email_template || ( (SL::DB::Default->get->templates || "templates/webpages") . "/periodic_invoices_email.txt" );
  my %params         = ( POSTED_INVOICES  => $posted_invoices,
                         PRINTED_INVOICES => $printed_invoices );

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
  my ($invoice, $config) = @_;

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

  $form->prepare_for_printing;

  $form->throw_on_error(sub {
    eval {
      $form->parse_template(\%::myconfig);
      1;
    } || die $EVAL_ERROR->getMessage;
  });
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
