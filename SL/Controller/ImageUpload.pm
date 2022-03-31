package SL::Controller::ImageUpload;

use strict;
use parent qw(SL::Controller::Base);

use JSON qw(to_json);

use SL::DB::Part;
use SL::DB::Order;
use SL::DB::DeliveryOrder;

use Rose::Object::MakeMethods::Generic
(
  scalar => [ qw() ],
  'scalar --get_set_init' => [ qw(object_type object) ],
);

my %object_loader = (
  part            => [ "SL::DB::Part" ],
  sales_order     => [ "SL::DB::Order", [ sales => 1, quotation => 0 ] ],
  sales_quotation => [ "SL::DB::Order", [ sales => 1, quotation => 1 ] ],
  purchase_order  => [ "SL::DB::Order", [ sales => 0, quotation => 1 ] ],
  sales_delivery_order => [ "SL::DB::DeliveryOrder", [ order_type => 'sales_delivery_order' ] ],
);


################ actions #################

sub action_upload_image {
  my ($self) = @_;

  $::request->layout->add_javascripts('kivi.File.js');
  $::request->layout->add_javascripts('kivi.FileDB.js');
  $::request->layout->add_javascripts('kivi.ImageUpload.js');

  $self->render('image_upload/local_list');
}

sub action_resolve_object_by_number {
  my ($self) = @_;

  my $result = {
    id          => $self->object->id,
    description => $self->object->displayable_name,
  };

  $self->render(\ to_json($result), { process => 0, type => 'json' });
}

################# internal ###############

sub accept_types {
  "image/*"
}

sub init_object_type {
  $::form->{object_type} or die "need object type"
}

sub init_object {
  my ($self) = @_;

  return unless $self->object_type;

  my $loader = $object_loader{ $self->object_type } or die "unknown object type";
  my $manager = $loader->[0]->_get_manager_class;

  return $manager->find_by(id => $::form->{object_id}*1) if $::form->{object_id};

  return $manager->find_by(donumber => $::form->{object_number}, closed => 0, @{ $loader->[1] // [] }) if $::form->{object_number};
}


1;


