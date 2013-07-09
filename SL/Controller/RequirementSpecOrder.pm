package SL::Controller::RequirementSpecOrder;

use strict;
use utf8;

use parent qw(SL::Controller::Base);

use SL::ClientJS;
use SL::DB::RequirementSpec;
use SL::DB::RequirementSpecOrder;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
  'scalar --get_set_init' => [ qw(requirement_spec js) ],
);

__PACKAGE__->run_before('setup');

#
# actions
#


sub action_list {
  my ($self) = @_;

  $::lxdebug->dump(0, "hmm", $self->requirement_spec->sections_sorted);
  $self->render('requirement_spec_order/list', { layout => 0 });
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

1;
