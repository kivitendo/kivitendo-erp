package SL::BackgroundJob::MassDeliveryOrderPrinting;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::DeliveryOrder;
use SL::DB::Order;  # origin order to delivery_order
use SL::DB::Printer;
use SL::SessionFile;
use SL::Template;
use SL::Helper::MassPrintCreatePDF qw(:all);
use SL::Helper::CreatePDF qw(:all);
use SL::Helper::File qw(store_pdf append_general_pdf_attachments doc_storage_enabled);

use constant WAITING_FOR_EXECUTION       => 0;
use constant PRINTING_DELIVERY_ORDERS    => 1;
use constant DONE                        => 2;

# Data format:
# my $data             = {
#   record_ids          => [ 123, 124, 127, ],
#   printer_id         => 4711,
#   num_created        => 0,
#   num_printed        => 0,
#   printed_ids        => [ 234, 235, ],
#   conversion_errors  => [ { id => 124, number => 'A981723', message => "Stuff went boom" }, ],
#   print_errors       => [ { id => 234, number => 'L87123123', message => "Printer is out of coffee" }, ],
#   pdf_file_name      => 'qweqwe.pdf',
#   session_id         => $::auth->get_session_id,
# };


sub convert_deliveryorders_to_pdf {
  my ($self) = @_;

  my $job_obj = $self->{job_obj};
  my $db      = $job_obj->db;

  $job_obj->set_data(status => PRINTING_DELIVERY_ORDERS())->save;
  my $data   = $job_obj->data_as_hash;

  my $printer_id = $data->{printer_id};
  if ( $data->{media} ne 'printer' ) {
      undef $printer_id;
      $data->{media} = 'file';
  }
  my %variables  = (
    type         => 'delivery_order',
    formname     =>  $data->{formname},
    format       =>  $data->{format},
    media        =>  $data->{media},
    printer_id   =>  $printer_id,
    copies       =>  $data->{copies},
  );

  my @pdf_file_names;
  foreach my $delivery_order_id (@{ $data->{record_ids} }) {
    my $number = $delivery_order_id;
    my $delivery_order = SL::DB::DeliveryOrder->new(id => $delivery_order_id)->load;

    eval {
      $number = $delivery_order->donumber;

      my %params = (
        variables  => \%variables,
        document   => $delivery_order,
        return     => 'file_name',
       );

      push @pdf_file_names, $self->create_massprint_pdf(%params);

      $data->{num_created}++;

      1;

    } or do {
      push @{ $data->{conversion_errors} }, { id => $delivery_order->id, number => $number, message => $@ };
    };

    $job_obj->update_attributes(data_as_hash => $data);
  }

  $self->merge_massprint_pdf(file_names => \@pdf_file_names, type => 'delivery_order' ) if scalar(@pdf_file_names) > 0;
}

sub run {
  my ($self, $job_obj) = @_;

  $self->{job_obj}         = $job_obj;

  $self->convert_deliveryorders_to_pdf;
  $self->print_pdfs;

  my $data       = $job_obj->data_as_hash;
  $data->{num_printed} =  $data->{num_created};
  $job_obj->update_attributes(data_as_hash => $data);
  $job_obj->set_data(status => DONE())->save;

  return 1;
}

1;
