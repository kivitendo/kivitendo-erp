package SL::Controller::RequirementSpecOrder;

use strict;
use utf8;

use parent qw(SL::Controller::Base);

use SL::ClientJS;
use SL::DB::Part;
use SL::DB::RequirementSpec;
use SL::DB::RequirementSpecOrder;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => [ qw(requirement_spec js all_parts) ],
);

__PACKAGE__->run_before('setup');

#
# actions
#


sub action_list {
  my ($self) = @_;

  $self->render('requirement_spec_order/list', { layout => 0 });
}

sub action_edit_assignment {
  my ($self) = @_;

  my $html   = $self->render('requirement_spec_order/edit_assignment', { output => 0 }, make_part_title => sub { $_[0]->partnumber . ' ' . $_[0]->description });
  $self->js->html('#ui-tabs-4', $html)
           ->render($self);
}

sub action_save_assignment {
  my ($self)   = @_;
  my $sections = $::form->{sections} || [];
  SL::DB::RequirementSpecItem->new(id => $_->{id})->load->update_attributes(order_part_id => ($_->{order_part_id} || undef)) for @{ $sections };

  my $html = $self->render('requirement_spec_order/list', { output => 0 });
  $self->js->html('#ui-tabs-4', $html)
           ->render($self);
}

sub action_cancel {
  my ($self) = @_;

  my $html = $self->render('requirement_spec_order/list', { output => 0 });
  $self->js->html('#ui-tabs-4', $html)
           ->render($self);
}

#
# filters
#

sub setup {
  my ($self) = @_;

  $::auth->assert('sales_quotation_edit');
  $::request->{layout}->use_stylesheet("${_}.css") for qw(jquery.contextMenu requirement_spec);
  $::request->{layout}->use_javascript("${_}.js") for qw(jquery.jstree jquery/jquery.contextMenu client_js requirement_spec);

  return 1;
}

sub init_requirement_spec {
  my ($self) = @_;
  $self->requirement_spec(SL::DB::RequirementSpec->new(id => $::form->{requirement_spec_id})->load) if $::form->{requirement_spec_id};
}

sub init_js {
  my ($self) = @_;
  $self->js(SL::ClientJS->new);
}

#
# helpers
#

sub init_all_parts { SL::DB::Manager::Part->get_all_sorted }

1;
