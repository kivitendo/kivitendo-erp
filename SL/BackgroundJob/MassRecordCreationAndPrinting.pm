package SL::BackgroundJob::MassRecordCreationAndPrinting;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::DeliveryOrder;
use SL::DB::Order;  # origin order to delivery_order
use SL::DB::Invoice;
use SL::DB::Printer;
use SL::SessionFile;
use SL::Template;
use SL::Locale::String qw(t8);
use SL::Helper::MassPrintCreatePDF qw(:all);
use SL::Helper::CreatePDF qw(:all);
use SL::Helper::File qw(store_pdf append_general_pdf_attachments doc_storage_enabled);

use constant WAITING_FOR_EXECUTION       => 0;
use constant CONVERTING_DELIVERY_ORDERS  => 1;
use constant PRINTING_INVOICES           => 2;
use constant DONE                        => 3;

# Data format:
# my $data             = {
#   record_ids          => [ 123, 124, 127, ],
#   printer_id         => 4711,
#   copy_printer_id    => 4711,
#   transdate          => $today || $custom_transdate,
#   num_created        => 0,
#   num_printed        => 0,
#   invoice_ids        => [ 234, 235, ],
#   conversion_errors  => [ { id => 124, number => 'A981723', message => "Stuff went boom" }, ],
#   print_errors       => [ { id => 234, number => 'L87123123', message => "Printer is out of coffee" }, ],
#   pdf_file_name      => 'qweqwe.pdf',
#   session_id         => $::auth->get_session_id,
# };

sub create_invoices {
  my ($self)  = @_;

  my $job_obj = $self->{job_obj};
  my $db      = $job_obj->db;

  $job_obj->set_data(status => CONVERTING_DELIVERY_ORDERS())->save;

  foreach my $delivery_order_id (@{ $job_obj->data_as_hash->{record_ids} }) {
    my $number = $delivery_order_id;
    my $data   = $job_obj->data_as_hash;

    eval {
      my $sales_delivery_order = SL::DB::DeliveryOrder->new(id => $delivery_order_id)->load;
      $number                  = $sales_delivery_order->donumber;
      my %conversion_params    = $data->{transdate} ? ('attributes' => { transdate => $data->{transdate} }) : ();
      my $invoice              = $sales_delivery_order->convert_to_invoice(%conversion_params);

      die $db->error if !$invoice;

      $data->{num_created}++;
      push @{ $data->{invoice_ids} }, $invoice->id;
      push @{ $self->{invoices}    }, $invoice;

      1;
    } or do {
      push @{ $data->{conversion_errors} }, { id => $delivery_order_id, number => $number, message => $@ };
    };

    $job_obj->update_attributes(data_as_hash => $data);
  }
}

sub convert_invoices_to_pdf {
  my ($self) = @_;

  return if !@{ $self->{invoices} };

  my $job_obj = $self->{job_obj};
  my $db      = $job_obj->db;

  $job_obj->set_data(status => PRINTING_INVOICES())->save;
  my $data = $job_obj->data_as_hash;

  my $printer_id = $data->{printer_id};
  if ( $data->{media} ne 'printer' ) {
      undef $printer_id;
      $data->{media} = 'file';
  }
  my %variables  = (
    type         => 'invoice',
    formname     => 'invoice',
    format       => 'pdf',
    media        => $printer_id ? 'printer' : 'file',
    printer_id   => $printer_id,
  );

  my @pdf_file_names;

  foreach my $invoice (@{ $self->{invoices} }) {

    eval {
      my @errors = ();
      my %params = (
        variables => \%variables,
        return    => 'file_name',
        document  => $invoice,
        errors    => \@errors,
      );
      push @pdf_file_names, $self->create_massprint_pdf(%params);
      $data->{num_printed}++;

      if (scalar @errors) {
        push @{ $data->{print_errors} }, { id => $invoice->id, number => $invoice->invnumber, message => join(', ', @errors) };
      }

      1;

    } or do {
      push @{ $data->{print_errors} }, { id => $invoice->id, number => $invoice->invnumber, message => $@ };
    };

    $job_obj->update_attributes(data_as_hash => $data);
  }

  $self->merge_massprint_pdf(file_names => \@pdf_file_names, type => 'invoice' ) if scalar(@pdf_file_names) > 0;
}

sub run {
  my ($self, $job_obj) = @_;

  $self->{job_obj}         = $job_obj;
  $self->{invoices} = [];

  $self->create_invoices;
  $self->convert_invoices_to_pdf;
  $self->print_pdfs;

  $job_obj->set_data(status => DONE())->save;

  return 1;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::BackgroundJob::MassRecordCreationAndPrinting

=head1 SYNOPSIS

In controller:

use SL::BackgroundJob::MassRecordCreationAndPrinting

my $job              = SL::DB::BackgroundJob->new(
    type               => 'once',
    active             => 1,
    package_name       => 'MassRecordCreationAndPrinting',

  )->set_data(
    record_ids         => [ map { $_->id } @records[0..$num - 1] ],
    printer_id         => $::form->{printer_id},
    copy_printer_id    => $::form->{copy_printer_id},
    transdate          => $::form->{transdate} || undef,
    status             => SL::BackgroundJob::MassRecordCreationAndPrinting->WAITING_FOR_EXECUTION(),
    num_created        => 0,
    num_printed        => 0,
    invoice_ids        => [ ],
    conversion_errors  => [ ],
    print_errors       => [ ],

  )->update_next_run_at;
  SL::System::TaskServer->new->wake_up;

=head1 OVERVIEW

This background job has 4 states which are described by the four constants above.

=over 2

=item * WAITING_FOR_EXECUTION
  Background has been initialised and needs to be picked up by the task_server

=item * CONVERTING_DELIVERY_ORDERS
   Object conversion

=item * PRINTING_INVOICES
  Printing, if done via print command

=item * DONE
  To release the process and for the user information

=back

=head1 FUNCTIONS

=over 2

=item C<create_invoices>

Converts the source objects (DeliveryOrder) to destination objects (Invoice).
On success objects will be saved.
If param C<data->{transdate}> is set, this will be the transdate. No safety checks are done.
The original conversion from order to delivery order had a post_save_sanity_check
C<$delivery_order-E<gt>post_save_sanity_check; # just a hint at e8521eee (#90 od)>
The params of convert_to_invoice are created on the fly with a anonym sub, as a alternative check
 perlsecret Enterprise ()x!!

=item C<convert_invoices_to_pdf>

Takes the new destination objects and merges them via print template in one pdf.

=item C<print_pdfs>

Sent the pdf to the printer command.
If param C<data->{copy_printer_id}> is set, the pdf will be sent to a second printer command.

=back

=head1 BUGS

Currently the calculation from the gui (form) differs from the calculation via convert (PTC).
Furthermore mass conversion with foreign currencies could lead to problems (daily rate check).

=head1 TODO

It would be great to extend this Job for general background printing. The original project
code converted sales order to delivery orders (84e7c540) this could be merged in unstable.
The states should be CONVERTING_SOURCE_RECORDS, PRINTING_DESTINATION_RECORDS etc

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

Jan Büren E<lt>jan@kivitendo-premium.deE<gt>

=cut
