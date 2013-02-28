package SL::Controller::RecordLinks;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::Order;
use SL::DB::DeliveryOrder;
use SL::DB::Invoice;
use SL::DB::PurchaseInvoice;
use SL::Locale::String;

__PACKAGE__->run_before('check_object_params', only => [ qw(ajax_list ajax_delete) ]);

#
# actions
#

sub action_ajax_list {
  my ($self) = @_;

  eval {
    my $model          = 'SL::DB::' . $::form->{object_model};
    my $object         = $model->new(id => $::form->{object_id})->load || die $::locale->text("Record not found");
    my $linked_records = $object->linked_records(direction => 'both');
    my $output         = SL::Presenter->get->grouped_record_list(
      $linked_records,
      with_columns      => [ qw(record_link_direction) ],
      edit_record_links => 1,
      object_model      => $::form->{object_model},
      object_id         => $::form->{object_id},
    );
    $self->render(\$output, { layout => 0, process => 0 });

    1;
  } or do {
    $self->render('generic/error', { layout => 0 }, label_error => $@);
  };
}

sub action_ajax_delete {
  my ($self) = @_;

  my $prefix = $::form->{form_prefix} || 'record_links';
  foreach my $str (@{ $::form->{"${prefix}_delete"} || [] }) {
    my ($from_table, $from_id, $to_table, $to_id) = split m/__/, $str, 4;
    $from_id *= 1;
    $to_id   *= 1;

    next if !$from_table || !$from_id || !$to_table || !$to_id;

    # $::lxdebug->message(0, "INSERT INTO record_links (from_table, from_id, to_table, to_id) VALUES ('${from_table}', ${from_id}, '${to_table}', ${to_id});");

    SL::DB::Manager::RecordLink->delete_all(where => [
      from_table => $from_table,
      from_id    => $from_id,
      to_table   => $to_table,
      to_id      => $to_id,
    ]);
  }

  $self->action_ajax_list;
}

#
# filters
#

sub check_object_params {
  my ($self) = @_;

  return $::form->{object_id} && ($::form->{object_model} =~ m/^(?:Order|DeliveryOrder|Invoice|PurchaseInvoice)$/);
}

1;
