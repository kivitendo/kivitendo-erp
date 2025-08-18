package SL::Controller::MassDeliveryOrderPrint;

use strict;

use parent qw(SL::Controller::Base);

use File::Slurp ();
use File::Copy;
use List::MoreUtils qw(uniq);
use List::Util qw(first);

use SL::Controller::Helper::GetModels;
use SL::BackgroundJob::MassDeliveryOrderPrinting;
use SL::DB::Customer;
use SL::DB::DeliveryOrder;
use SL::DB::Order;
use SL::DB::Part;
use SL::DB::Printer;
use SL::Helper::MassPrintCreatePDF qw(:all);
use SL::Helper::CreatePDF qw(:all);
use SL::Helper::File qw(store_pdf append_general_pdf_attachments doc_storage_enabled);
use SL::Helper::PrintOptions;
use SL::Helper::Flash;
use SL::Locale::String;
use SL::SessionFile;
use SL::System::TaskServer;

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => [ qw(delivery_order_models delivery_order_ids printers filter_summary temp_files) ],
);

__PACKAGE__->run_before('setup');

#
# actions
#
sub action_list_delivery_orders {
  my ($self) = @_;

  my $show = ($::form->{noshow}?0:1);
  delete $::form->{noshow};

  if ($::form->{ids}) {
    my $key = 'MassDeliveryOrderPrint::ids-' . $::form->{ids};
    $self->delivery_order_ids($::auth->get_session_value($key) || []);
    $self->delivery_order_models->add_additional_url_params(ids => $::form->{ids});
  }

  my %selected_ids = map { +($_ => 1) } @{ $self->delivery_order_ids };

  my $pr = SL::DB::Manager::Printer->find_by(
      printer_description => $::locale->text("sales_delivery_order_printer"));
  if ($pr ) {
      $::form->{printer_id} = $pr->id;
  }
  $self->render('mass_delivery_order_print/list_delivery_orders',
                title        => $::locale->text('Print delivery orders'),
                nowshow      => $show,
                print_opt    => $self->print_options(hide_language_id => 1),
                selected_ids => \%selected_ids);
}

sub action_mass_mdo_download {
  my ($self) = @_;
  my $job    = SL::DB::BackgroundJob->new(id => $::form->{job_id})->load;

  my $sfile  = SL::SessionFile->new($job->data_as_hash->{pdf_file_name}, mode => 'r');
  die $! if !$sfile->fh;

  my $merged_pdf = do { local $/; my $fh = $sfile->fh; <$fh> };
  $sfile->fh->close;

  my $file_name =  t8('Sales Delivery Orders') . '-' . DateTime->now_local->strftime('%Y%m%d%H%M%S') . '.pdf';
  $file_name    =~ s{[^\w\.]+}{_}g;

  return $self->send_file(
    \$merged_pdf,
    type => 'application/pdf',
    name => $file_name,
  );
}

sub action_mass_mdo_status {
  my ($self) = @_;
  $::lxdebug->enter_sub();
  eval {
    my $job = SL::DB::BackgroundJob->new(id => $::form->{job_id})->load;
    my $html = $self->render('mass_delivery_order_print/_print_status', { output => 0 }, job => $job);

    $self->js->html('#mass_print_dialog', $html);
    if ( $job->data_as_hash->{status} == SL::BackgroundJob::MassDeliveryOrderPrinting->DONE() ) {
      foreach my $dorder_id (@{$job->data_as_hash->{record_ids}}) {
        $self->js->prop('#multi_id_id_'.$dorder_id,'checked',0);
      }
      $self->js->prop('#multi_all','checked',0);
      $self->js->run('kivi.MassDeliveryOrderPrint.massConversionFinished');
    }
    1;
  } or do {
    $self->js->run('kivi.MassDeliveryOrderPrint.massConversionFinished')
      ->run('kivi.MassDeliveryOrderPrint.massConversionFinishProcess')
      ->flash('error', t8('No such job #1 in the database.',$::form->{job_id}));
  };
  $self->js->render;

  $::lxdebug->leave_sub();
}

sub action_mass_mdo_print {
  my ($self) = @_;
  $::lxdebug->enter_sub();

  eval {
    my @do_ids = @{ $::form->{id} || [] };
    push @do_ids, map { $::form->{"trans_id_$_"} } grep { $::form->{"multi_id_$_"} } (1..$::form->{rowcount});

    my @delivery_orders = map { SL::DB::DeliveryOrder->new(id => $_)->load } @do_ids;

    if (!@delivery_orders) {
      $self->js->flash('error', t8('No delivery orders have been selected.'));
    } else {
      my $job              = SL::DB::BackgroundJob->new(
        type               => 'once',
        active             => 1,
        package_name       => 'MassDeliveryOrderPrinting',

      )->set_data(
        record_ids         => [ @do_ids ],
        printer_id         => $::form->{printer_id},
        formname           => $::form->{formname},
        format             => $::form->{format},
        media              => $::form->{media},
        bothsided          => ($::form->{bothsided}?1:0),
        copies             => $::form->{copies},
        status             => SL::BackgroundJob::MassDeliveryOrderPrinting->WAITING_FOR_EXECUTION(),
        num_created        => 0,
        num_printed        => 0,
        printed_ids        => [ ],
        conversion_errors  => [ ],
        print_errors       => [ ],
        session_id         => $::auth->get_session_id,

      )->update_next_run_at;

      SL::System::TaskServer->new->wake_up;
      my $html = $self->render('mass_delivery_order_print/_print_status', { output => 0 }, job => $job);

      $self->js
        ->html('#mass_print_dialog', $html)
        ->run('kivi.MassDeliveryOrderPrint.massConversionPopup')
        ->run('kivi.MassDeliveryOrderPrint.massConversionStarted');
    }
    1;
  } or do {
    my $errstr = $@;
    $self->js->flash('error',
      t8('Document generating failed. Please check Templates an LateX !'),
      $errstr
    );
  };
  $self->js->render;
  $::lxdebug->leave_sub();
}

sub action_downloadpdf {
  my ($self) = @_;
  $::lxdebug->enter_sub();
  if ( $::form->{filename} ) {
    my $content = scalar File::Slurp::read_file($::form->{filename});
    my $file_name = $::form->get_formname_translation($::form->{formname}) .
      '-' . DateTime->now_local->strftime('%Y%m%d%H%M%S') . '.pdf';
    $file_name    =~ s{[^\w\.]+}{_}g;

    unlink($::form->{filename});

    return $self->send_file(
      \$content,
      type => 'application/pdf',
      name => $file_name,
    );
  } else {
    flash('error', t8('No filename exists!'));
  }
  $::lxdebug->leave_sub();
}

#
# filters
#

sub init_printers { SL::DB::Manager::Printer->get_all_sorted }
sub init_delivery_order_ids { [] }
sub init_temp_files { [] }

sub init_delivery_order_models {
  my ($self)             = @_;
  my @delivery_order_ids = @{ $self->delivery_order_ids };

  SL::Controller::Helper::GetModels->new(
    controller   => $_[0],
    model        => 'DeliveryOrder',
    (paginated   => 0,) x !!@delivery_order_ids,
    sorted       => {
      _default     => {
        by           => 'reqdate',
        dir          => 0,
      },
      customer     => t8('Customer'),
      donumber     => t8('Delivery Order Number'),
      employee     => t8('Employee'),
      ordnumber    => t8('Order Number'),
      reqdate      => t8('Delivery Date'),
      transdate    => t8('Date'),
    },
    with_objects => [ qw(customer employee) ],
    query        => [
      '!customer_id' => undef,
      or             => [ closed    => undef, closed    => 0 ],
      (id            => \@delivery_order_ids) x !!@delivery_order_ids,
    ],
  );
}

sub init_filter_summary {
  my ($self) =@_;
  my $filter = $::form->{filter} || { customer => {}, shipto => {}, };

  my @filters;
  push @filters, t8('Customer')                              . ' ' . $filter->{customer}->{'name:substr::ilike'}     if $filter->{customer}->{'name:substr::ilike'};
  push @filters, t8('Shipping address (name)')               . ' ' . $filter->{shipto}->{'shiptoname:substr::ilike'} if $filter->{shipto}->{'shiptoname:substr::ilike'};
  push @filters, t8('Delivery Date') . ' ' . t8('From Date') . ' ' . $filter->{'reqdate:date::ge'}                   if $filter->{'reqdate:date::ge'};
  push @filters, t8('Delivery Date') . ' ' . t8('To Date')   . ' ' . $filter->{'reqdate:date::le'}                   if $filter->{'reqdate:date::le'};

  return join ', ', @filters;
}

sub setup {
  my ($self) = @_;
  $::auth->assert('sales_delivery_order_edit');
  $::request->layout->use_javascript("${_}.js")  for qw(kivi.MassDeliveryOrderPrint);
}


sub generate_documents {
  my ($self, @delivery_orders) = @_;

  my %pdf_params = (
    'documents'       => \@delivery_orders ,
    'variables'       => {
      'type'            => $::form->{type},
      'formname'        => $::form->{formname},
      'language_id'     => '',
      'format'          => 'pdf',
      'media'           => 'file',
      'printer_id'      => $::form->{printer_id},
    });

  my ($temp_fh, $outname) = File::Temp::tempfile(
    'kivitendo-outfileXXXXXX',
    SUFFIX => '.pdf',
    DIR    => $::lx_office_conf{paths}->{userspath},
    UNLINK => 0,
  );
  close $temp_fh;

  my @pdf_file_names = $self->create_pdfs(%pdf_params);
  my $fcount = scalar(@pdf_file_names);
  if ( $fcount < 2 ) {
    copy($pdf_file_names[0],$outname);
  } else {
    if ( !$self->merge_pdfs(file_names => \@pdf_file_names, out_path => $outname, bothsided => $::form->{bothsided} )) {
      $::lxdebug->leave_sub();
      return 0;
    }
  }
  foreach my $dorder (@delivery_orders) {
    $self->js->prop('#multi_id_id_'.$dorder->id,'checked',0);
  }
  $self->js->prop('#multi_all','checked',0);
  return $outname;
}

1;
