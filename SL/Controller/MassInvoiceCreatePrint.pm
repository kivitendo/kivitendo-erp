package SL::Controller::MassInvoiceCreatePrint;

use strict;

use parent qw(SL::Controller::Base);

use File::Slurp ();
use List::MoreUtils qw(all uniq);
use List::Util qw(first min);

use SL::BackgroundJob::MassRecordCreationAndPrinting;
use SL::Controller::Helper::GetModels;
use SL::DB::DeliveryOrder;
use SL::DB::Order;
use SL::DB::Printer;
use SL::Helper::MassPrintCreatePDF qw(:all);
use SL::Helper::CreatePDF qw(:all);
use SL::Helper::File qw(store_pdf append_general_pdf_attachments doc_storage_enabled);
use SL::Helper::Flash;
use SL::Locale::String;
use SL::SessionFile;
use SL::System::TaskServer;
use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => [ qw(invoice_models invoice_ids sales_delivery_order_models printers default_printer_id today all_businesses) ],
);

__PACKAGE__->run_before('setup');

#
# actions
#

sub action_list_sales_delivery_orders {
  my ($self) = @_;

  # default is usually no show, exception here
  my $show = ($::form->{noshow} ? 0 : 1);
  delete $::form->{noshow};

  # if a filter is choosen, the filter info should be visible
  $self->make_filter_summary;
  $self->setup_list_sales_delivery_orders_action_bar(show_creation_buttons => $show, num_rows => scalar(@{ $self->sales_delivery_order_models->get }));
  $self->render('mass_invoice_create_print_from_do/list_sales_delivery_orders',
                noshow  => $show,
                title   => $::locale->text('Open sales delivery orders'));
}

sub action_create_invoices {
  my ($self) = @_;

  my @sales_delivery_order_ids = @{ $::form->{id} || [] };
  if (!@sales_delivery_order_ids) {
    # should never be executed, double catch via js
    flash_later('error', t8('No delivery orders have been selected.'));
    return $self->redirect_to(action => 'list_sales_delivery_orders');
  }

  my $db = SL::DB::Invoice->new->db;
  my @invoices;
  my @already_closed_delivery_orders;

  if (!$db->with_transaction(sub {
    foreach my $id (@sales_delivery_order_ids) {
      my $delivery_order    = SL::DB::DeliveryOrder->new(id => $id)->load;

      # Only process open delivery orders. In this list should only be open
      # delivery orders, but if the user clicked browser back, a new creation
      # of invoices for delivery orders which are closed now can be triggered.
      # Prevent this.
      if ($delivery_order->closed) {
        push @already_closed_delivery_orders, $delivery_order;

      } else {
        my $invoice = $delivery_order->convert_to_invoice() || die $db->error;
        push @invoices, $invoice;
      }
    }

    1;
  })) {
    $::lxdebug->message(LXDebug::WARN(), "Error: " . $db->error);
    $::form->error($db->error);
  }

  my $key = sprintf('%d-%d', Time::HiRes::gettimeofday());
  $::auth->set_session_value("MassInvoiceCreatePrint::ids-${key}" => [ map { $_->id } @invoices ]);

  if (@already_closed_delivery_orders) {
    my $dos_list = join ' ', map { $_->donumber } @already_closed_delivery_orders;
    flash_later('error', t8('The following delivery orders could not be processed because they are already closed: #1', $dos_list));
  }

  flash_later('info', t8('The invoices have been created. They\'re pre-selected below.')) if @invoices;

  $self->redirect_to(action => 'list_invoices', ids => $key);
}

sub action_list_invoices {
  my ($self) = @_;

  my $show = $::form->{noshow} ? 0 : 1;
  delete $::form->{noshow};

  if ($::form->{ids}) {
    my $key = 'MassInvoiceCreatePrint::ids-' . $::form->{ids};
    $self->invoice_ids($::auth->get_session_value($key) || []);

    # Prevent models->get to retrieve any invoices if session key is there
    # but no ids are given.
    $self->invoice_ids([0]) if !@{$self->invoice_ids};

    $self->invoice_models->add_additional_url_params(ids => $::form->{ids});
  }

  my %selected_ids = map { +($_ => 1) } @{ $self->invoice_ids };

  $::form->{printer_id} ||= $self->default_printer_id;

  $self->setup_list_invoices_action_bar(num_rows => scalar(@{ $self->invoice_models->get }));

  $self->render('mass_invoice_create_print_from_do/list_invoices',
                title        => $::locale->text('Open invoice'),
                noshow       => $show,
                selected_ids => \%selected_ids);
}

sub action_print {
  my ($self) = @_;

  my @invoices = map { SL::DB::Invoice->new(id => $_)->load } @{ $::form->{id} || [] };
  if (!@invoices) {
    flash_later('error', t8('No invoices have been selected.'));
    return $self->redirect_to(action => 'list_invoices');
  }

  $self->download_or_print_documents(printer_id => $::form->{printer_id}, invoices => \@invoices, bothsided => $::form->{bothsided});
}

sub action_create_print_all_start {
  my ($self) = @_;

  $self->sales_delivery_order_models->disable_plugin('paginated');

  my @records          = @{ $self->sales_delivery_order_models->get };
  my $num              = min(scalar(@records), $::form->{number_of_invoices} // scalar(@records));

  my $job              = SL::DB::BackgroundJob->new(
    type               => 'once',
    active             => 1,
    package_name       => 'MassRecordCreationAndPrinting',

  )->set_data(
    record_ids         => [ map { $_->id } @records[0..$num - 1] ],
    printer_id         => $::form->{printer_id},
    copy_printer_id    => $::form->{copy_printer_id},
    bothsided          => ($::form->{bothsided}?1:0),
    transdate          => $::form->{transdate},
    status             => SL::BackgroundJob::MassRecordCreationAndPrinting->WAITING_FOR_EXECUTION(),
    num_created        => 0,
    num_printed        => 0,
    invoice_ids        => [ ],
    conversion_errors  => [ ],
    print_errors       => [ ],
    session_id         => $::auth->get_session_id,

  )->update_next_run_at;

  SL::System::TaskServer->new->wake_up;

  my $html = $self->render('mass_invoice_create_print_from_do/_create_print_all_status', { output => 0 }, job => $job);

  $self->js
    ->html('#create_print_all_dialog', $html)
    ->run('kivi.MassInvoiceCreatePrint.massConversionStarted')
    ->render;
}

sub action_create_print_all_status {
  my ($self) = @_;
  my $job    = SL::DB::BackgroundJob->new(id => $::form->{job_id})->load;
  my $html   = $self->render('mass_invoice_create_print_from_do/_create_print_all_status', { output => 0 }, job => $job);

  $self->js->html('#create_print_all_dialog', $html);
  $self->js->run('kivi.MassInvoiceCreatePrint.massConversionFinished') if $job->data_as_hash->{status} == SL::BackgroundJob::MassRecordCreationAndPrinting->DONE();
  $self->js->render;
}

sub action_create_print_all_download {
  my ($self) = @_;
  my $job    = SL::DB::BackgroundJob->new(id => $::form->{job_id})->load;

  my $sfile  = SL::SessionFile->new($job->data_as_hash->{pdf_file_name}, mode => 'r');
  die $! if !$sfile->fh;

  my $merged_pdf = do { local $/; my $fh = $sfile->fh; <$fh> };
  $sfile->fh->close;

  my $type      = 'Invoices';
  my $file_name =  t8($type) . '-' . DateTime->now_local->strftime('%Y%m%d%H%M%S') . '.pdf';
  $file_name    =~ s{[^\w\.]+}{_}g;

  return $self->send_file(
    \$merged_pdf,
    type => 'application/pdf',
    name => $file_name,
  );
}

#
# filters
#

sub init_printers { SL::DB::Manager::Printer->get_all_sorted }
#sub init_att      { require SL::Controller::Attachments; SL::Controller::Attachments->new() }
sub init_invoice_ids { [] }
sub init_today         { DateTime->today_local }

sub init_sales_delivery_order_models {
  my ($self) = @_;
  return $self->_init_sales_delivery_order_models(sortby => 'donumber');
}

sub _init_sales_delivery_order_models {
  my ($self, %params) = @_;

  SL::Controller::Helper::GetModels->new(
    controller   => $_[0],
    model        => 'DeliveryOrder',
    # model        => 'Order',
    sorted       => {
      _default     => {
        by           => $params{sortby},
        dir          => 1,
      },
      customer     => t8('Customer'),
      employee     => t8('Employee'),
      transdate    => t8('Delivery Order Date'),
      donumber     => t8('Delivery Order Number'),
      ordnumber     => t8('Order Number'),
    },
    with_objects => [ qw(customer employee) ],
   query        => [
      '!customer_id' => undef,
      or             => [ closed    => undef, closed    => 0 ],
    ],
  );
}


sub init_invoice_models {
  my ($self)             = @_;
  my @invoice_ids = @{ $self->invoice_ids };

  SL::Controller::Helper::GetModels->new(
    controller   => $_[0],
    model        => 'Invoice',
    (paginated   => 0,) x !!@invoice_ids,
    sorted       => {
      _default     => {
        by           => 'transdate',
        dir          => 0,
      },
      customer     => t8('Customer'),
      invnumber    => t8('Invoice Number'),
      employee     => t8('Employee'),
      donumber     => t8('Delivery Order Number'),
      ordnumber    => t8('Order Number'),
      reqdate      => t8('Delivery Date'),
      transdate    => t8('Date'),
    },
    with_objects => [ qw(customer employee) ],
    query        => [
      '!customer_id' => undef,
      (id            => \@invoice_ids) x !!@invoice_ids,
    ],
  );
}


sub init_default_printer_id {
  my $pr = SL::DB::Manager::Printer->find_by(printer_description => $::locale->text("sales_invoice_printer"));
  return $pr ? $pr->id : undef;
}

sub init_all_businesses {
  return SL::DB::Manager::Business->get_all_sorted;
}

sub setup {
  my ($self) = @_;
  $::auth->assert('invoice_edit');

  $::request->layout->use_javascript("${_}.js")  for qw(kivi.MassInvoiceCreatePrint);
}

#
# helpers
#


sub download_or_print_documents {
  my ($self, %params) = @_;

  my @pdf_file_names;

  eval {
    my %pdf_params = (
      documents       => $params{invoices},
      variables       => {
        type        => 'invoice',
        formname    => 'invoice',
        format      => 'pdf',
        media       => $params{printer_id} ? 'printer' : 'file',
        printer_id  => $params{printer_id},
      });

    @pdf_file_names = $self->create_pdfs(%pdf_params);
    my $merged_pdf  = $self->merge_pdfs(file_names => \@pdf_file_names, bothsided => $params{bothsided});
    unlink @pdf_file_names;

    if (!$params{printer_id}) {
      my $file_name =  t8("Invoices") . '-' . DateTime->now_local->strftime('%Y%m%d%H%M%S') . '.pdf';
      $file_name    =~ s{[^\w\.]+}{_}g;

      return $self->send_file(
        \$merged_pdf,
        type => 'application/pdf',
        name => $file_name,
      );
    }

    my $printer = SL::DB::Printer->new(id => $params{printer_id})->load;
    $printer->print_document(content => $merged_pdf);

    flash_later('info', t8('The documents have been sent to the printer \'#1\'.', $printer->printer_description));
    return $self->redirect_to(action => 'list_invoices', printer_id => $params{printer_id});

  } or do {
    unlink @pdf_file_names;
    $::form->error(t8("Creating the PDF failed:") . " " . $@);
  };
}

sub make_filter_summary {
  my ($self) = @_;

  my $filter = $::form->{filter} || {};
  my @filter_strings;

  my @filters = (
    [ $filter->{customer}{"name:substr::ilike"}, t8('Customer') ],
    [ $filter->{"transdate:date::ge"},           t8('Delivery Order Date') . " " . t8('From Date') ],
    [ $filter->{"transdate:date::le"},           t8('Delivery Order Date') . " " . t8('To Date')   ],
  );

  for (@filters) {
    push @filter_strings, "$_->[1]: " . ($_->[2] ? $_->[2]->() : $_->[0]) if $_->[0];
  }

  $self->{filter_summary} = join ', ', @filter_strings;
}

sub setup_list_invoices_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#search_form', { action => 'MassInvoiceCreatePrint/list_invoices' } ],
        accesskey => 'enter',
      ],
      action => [
        $::locale->text('Print'),
        call     => [ 'kivi.MassInvoiceCreatePrint.showMassPrintOptionsOrDownloadDirectly' ],
        disabled => !$params{num_rows} ? $::locale->text('The report doesn\'t contain entries.') : undef,
      ],
    );
  }
}

sub setup_list_sales_delivery_orders_action_bar {
  my ($self, %params) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        $params{show_creation_buttons} ? t8('Update') : t8('Search'),
        submit    => [ '#search_form', { action => 'MassInvoiceCreatePrint/list_sales_delivery_orders' } ],
        accesskey => 'enter',
      ],

      combobox => [
        action => [
          t8('Invoices'),
          tooltip => t8("Create and print invoices")
        ],
        action => [
          t8("Create and print invoices for all selected delivery orders"),
          submit    => [ 'form', { action => 'MassInvoiceCreatePrint/create_invoices' } ],
          disabled  => !$params{num_rows} ? $::locale->text('The report doesn\'t contain entries.') : undef,
          only_if   => $params{show_creation_buttons},
          checks    => [ 'kivi.MassInvoiceCreatePrint.checkDeliveryOrderSelection' ],
          only_once => 1,
        ],

        action => [
          t8("Create and print invoices for all delivery orders matching the filter"),
          call     => [ 'kivi.MassInvoiceCreatePrint.createPrintAllInitialize' ],
          disabled => !$params{num_rows} ? $::locale->text('The report doesn\'t contain entries.') : undef,
          only_if  => $params{show_creation_buttons},
        ],
      ],
    );
  }
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::MassInvoiceCreatePrint - Controller for Mass Create Print Sales Invoice from Delivery Order

=head2 OVERVIEW

Controller class for the conversion and processing (printing) of objects.


Inherited from the base controller class, this controller implements the Sales Mass Invoice Creation.
In general there are two major distinctions:
This class implements the conversion and the printing via clickable action AND triggers the same
conversion towards a Background-Job with a good user interaction.

Analysis hints: All this is more or less boilerplate code around the great convert_to_invoice method
in DeliverOrder.pm. If you need to debug stuff, take a look at the corresponding test case
($ t/test.pl t/db_helper/convert_invoices.t). There are some redundant code parts in this controller
and in the background job, i.e. compare the actions create and print.
From a reverse engineering point of view the actions in this controller were written before the
background job existed, therefore if anything goes boom take a look at the single steps done via gui
in this controller and after that take a deeper look at the MassRecordCreationAndPrinting job.

=head1 FUNCTIONS

=over 2

=item C<action_list_sales_delivery_orders>

List all open sales delivery orders. The filter can be in two states show or "no show" the
original, probably gorash idea, is to increase performance and not to be forced to click on the
next button (like in all other reports). Therefore use this option and this filter for a good
project default and hide it again. Filters can be added in _filter.html. Take a look at
  SL::Controlle::Helper::GetModels::Filtered.pm and SL::DB::Helper::Filtered.

=item C<action_create_invoices>

Creates or to be more correctly converts delivery orders to invoices. All items are
converted 1:1 and after conversion the delivery order(s) are closed.

=item C<action_list_invoices>

List the created invoices, if created via gui (see action above)

=item C<action_print>

Print the selected invoices. Yes, it really is all boring linear (see action above).
Calls download_or_print method.

=item C<action_create_print_all_start>

Initialises the webform for the creation and printing via background job. Now we get to
the more fun part ...  Mosu did a great user interaction job here, we can choose how many
objects are converted in one strike and if or if not they are downloadable or will be sent to
a printer (if defined as a printing command) right away.
Background job is started and status is watched via js and the next action.

=item C<action_create_print_all_status>

Action for watching status, default is refreshing every 5 seconds

=item C<action_create_print_all_download>

If the above is done (did I already said: boring linear?). Documents will
be either printed or downloaded.

=item C<init_printers>

Gets all printer commands

=item C<init_invoice_ids>

Gets a list of (empty) invoice ids

=item C<init_today>

Gets the current day. Currently used in custom code.
Has to be initialised (get_set_init) and can be used as default for
a date tag like C<[% L.date_tag("transdate", SELF.today, id=transdate) %]>.

=item C<init_sales_delivery_order_models>

Calls _init_sales_delivery_order_models with a param

=item C<_init_sales_delivery_order_models>

Private function, called by init_sales_delivery_order_models.
Gets all open sales delivery orders.

=item C<init_invoice_models>

Gets all invoice_models via the ids in invoice_ids (at the beginning no ids exist)

=item C<init_default_printer_id>

Gets the default printer for sales_invoices. Currently this function is not called, but
might be useful in the next version.Calling template code and Controller already expect a default:
C<L.select_tag("", printers, title_key="description", default=SELF.default_printer_id, id="cpa_printer_id") %]>

=item C<setup>

Currently sets / checks only the access right.

=item C<create_pdfs>

=item C<download_or_print_documents>

Backend function for printing or downloading docs. Only used for gui processing (called
via action_print).

=item C<make_filter_summary>
Creates the filter option summary in the header. By the time of writing three filters are
supported: Customer and date from/to of the Delivery Order (database field transdate).

=back

=head1 TODO

pShould be more generalized. Right now just one conversion (delivery order to invoice) is supported.
Using BackgroundJobs to mass create / transfer stuff is the way to do it. The original idea
was taken from one client project (mosu) with some extra (maybe not standard compliant) customized
stuff (using cvars for extra filters and a very compressed Controller for linking (ODSalesOrder.pm)).


=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

Jan Büren E<lt>jan@kivitendo-premium.deE<gt>

=cut
