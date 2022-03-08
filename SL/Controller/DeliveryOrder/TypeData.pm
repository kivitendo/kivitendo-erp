package SL::Controller::DeliveryOrder::TypeData;

use strict;
use Exporter qw(import);
use Scalar::Util qw(weaken);
use SL::Locale::String qw(t8);
use SL::DB::DeliveryOrder::TypeData qw(:types :subs);

my @export_types = qw(SALES_DELIVERY_ORDER_TYPE PURCHASE_DELIVERY_ORDER_TYPE SUPPLIER_DELIVERY_ORDER_TYPE RMA_DELIVERY_ORDER_TYPE);

our @EXPORT_OK = (@export_types);
our %EXPORT_TAGS = (types => \@export_types);

use Rose::Object::MakeMethods::Generic scalar => [ qw(c) ];

sub new {
  my ($class, $controller) = @_;
  my $o = bless {}, $class;

  if ($controller) {
    $o->c($controller);
    weaken($o->{c});
  }

  return $o;
}

sub validate {
  my ($self, $string) = @_;
  validate_type($string);
}

sub text {
  my ($self, $string) = @_;
  get3($self->c->type, "text", $string);
}

sub show_menu {
  my ($self, $string) = @_;
  get3($self->c->type, "show_menu", $string);
}

sub workflow {
  my ($self, $string) = @_;
  get3($self->c->type, "workflow", $string);
}

sub properties {
  my ($self, $string) = @_;
  get3($self->c->type, "properties", $string);
}

sub access {
  my ($self, $string) = @_;
  get3($_[0]->c->type, "rights", $string);
}

sub is_quotation {
  get3($_[0]->c->type, "properties", "is_quotation");
}

sub customervendor {
  get3($_[0]->c->type, "properties", "customervendor");
}

sub is_customer {
  get3($_[0]->c->type, "properties", "is_customer");
}

sub nr_key {
  get3($_[0]->c->type, "properties", "nr_key");
}

sub transfer {
  get3($_[0]->c->type, "properties", "transfer");
}

sub part_classification_query {
  my ($self, $string) = @_;
  get($self->c->type, "part_classification_query");
}

sub set_reqdate_by_type {
  my ($self) = @_;

  if (!$self->c->order->reqdate) {
    $self->c->order->reqdate(DateTime->today_local->next_workday(extra_days => 1));
  }
}

sub get_reqdate_by_type {
  my ($self, $reqdate, $saved_reqdate) = @_;

  if ($reqdate == $saved_reqdate) {
    return DateTime->today_local->next_workday(extra_days => 1);
  } else {
    return $reqdate;
  }
}

1;
