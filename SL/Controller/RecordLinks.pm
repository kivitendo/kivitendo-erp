package SL::Controller::RecordLinks;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::Order;
use SL::DB::DeliveryOrder;
use SL::DB::Invoice;
use SL::DB::PurchaseInvoice;
use SL::Locale::String;

#
# actions
#

sub action_ajax_list {
  my ($self) = @_;

  eval {
    die $::locale->text("Invalid parameters") if (!$::form->{object_id} || ($::form->{object_model} !~ m/^(?:Order|DeliveryOrder|Invoice|PurchaseInvoice)$/));

    my $model          = 'SL::DB::' . $::form->{object_model};
    my $object         = $model->new(id => $::form->{object_id})->load || die $::locale->text("Record not found");
    my $linked_records = $object->linked_records(direction => 'both');
    my $output         = SL::Presenter->get->grouped_record_list($linked_records, with_columns => [ qw(record_link_direction) ]);
    $self->render(\$output, { layout => 0, process => 0 });

    1;
  } or do {
    $self->render('generic/error', { layout => 0 }, label_error => $@);
  };
}

1;
