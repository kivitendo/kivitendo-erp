package SL::Controller::ImageUpload;

use strict;
use parent qw(SL::Controller::Base);

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
  sales_delivery_order => [ "SL::DB::DeliveryOrder", [ is_sales => 1 ] ],
);


################ actions #################

sub action_upload_image {
  my ($self) = @_;

  $::request->layout->add_javascripts('kivi.File.js');

  $self->render('image_upload/form');
}

################# internal ###############

sub init_object_type {
  $::form->{object_type} or die "need object type"
}

sub init_object {
  my ($self) = @_;

  return unless $self->object_type;

  my $loader = $object_loader{ $self->object_type } or die "unknown object type";
  my $manager = $loader->[0]->_get_manager_class;

  return $manager->find_by(id => $::form->{object_id}*1) if $::form->{object_id};

  return $manager->find_by(donumber => $::form->{object_number}, @{ $loader->[1] // [] }) if $::form->{object_number};
}


1;


