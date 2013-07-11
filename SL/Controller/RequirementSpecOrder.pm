package SL::Controller::RequirementSpecOrder;

use strict;
use utf8;

use parent qw(SL::Controller::Base);

use List::MoreUtils qw(uniq);
use List::Util qw(first);

use SL::ClientJS;
use SL::DB::Customer;
use SL::DB::Order;
use SL::DB::Part;
use SL::DB::RequirementSpec;
use SL::DB::RequirementSpecOrder;
use SL::Helper::Flash;
use SL::Locale::String;

use constant TAB_ID => 'ui-tabs-4';

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(parts) ],
  'scalar --get_set_init' => [ qw(requirement_spec js h_unit_name all_customers all_parts) ],
);

__PACKAGE__->run_before('setup');

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->render('requirement_spec_order/list', { layout => 0 });
}

sub action_new {
  my ($self) = @_;

  my $html   = $self->render('requirement_spec_order/new', { output => 0 }, make_part_title => sub { $_[0]->partnumber . ' ' . $_[0]->description });
  $self->js->html('#' . TAB_ID(), $html)
           ->render($self);
}

sub action_create {
  my ($self)         = @_;

  # 1. Update sections with selected part IDs.
  my $section_attrs  = $::form->{sections} || [];
  my $sections       = SL::DB::Manager::RequirementSpecItem->get_all(where => [ id => [ map { $_->{id} } @{ $section_attrs } ] ]);
  my %sections_by_id = map { ($_->{id} => $_) } @{ $sections };

  $sections_by_id{ $_->{id} }->update_attributes(order_part_id => $_->{order_part_id}) for @{ $section_attrs };

  # 2. Create actual quotation/order.
  my $order = $self->create_order(sections => $sections);
  $order->save;

  $self->requirement_spec->orders(
    @{ $self->requirement_spec->orders },
    SL::DB::RequirementSpecOrder->new(order => $order, version => $self->requirement_spec->version)
  );
  $self->requirement_spec->save;
  $self->init_requirement_spec;

  # 3. Notify the user and return to list.
  my $html = $self->render('requirement_spec_order/list', { output => 0 });
  $self->js->html('#' . TAB_ID(), $html)
           ->flash('info', $::form->{quotation} ? t8('Sales quotation #1 has been created.', $order->quonumber) : t8('Sales order #1 has been created.', $order->ordnumber))
           ->render($self);
}

sub action_edit_assignment {
  my ($self) = @_;

  my $html   = $self->render('requirement_spec_order/edit_assignment', { output => 0 }, make_part_title => sub { $_[0]->partnumber . ' ' . $_[0]->description });
  $self->js->html('#' . TAB_ID(), $html)
           ->render($self);
}

sub action_save_assignment {
  my ($self)   = @_;
  my $sections = $::form->{sections} || [];
  SL::DB::RequirementSpecItem->new(id => $_->{id})->load->update_attributes(order_part_id => ($_->{order_part_id} || undef)) for @{ $sections };

  my $html = $self->render('requirement_spec_order/list', { output => 0 });
  $self->js->html('#' . TAB_ID(), $html)
           ->render($self);
}

sub action_cancel {
  my ($self) = @_;

  my $html = $self->render('requirement_spec_order/list', { output => 0 });
  $self->js->html('#' . TAB_ID(), $html)
           ->render($self);
}

#
# filters
#

sub setup {
  my ($self) = @_;

  $::auth->assert('sales_quotation_edit');
  $::request->{layout}->use_stylesheet("${_}.css") for qw(jquery.contextMenu requirement_spec);
  $::request->{layout}->use_javascript("${_}.js")  for qw(jquery.jstree jquery/jquery.contextMenu client_js requirement_spec);

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

sub init_all_customers { SL::DB::Manager::Customer->get_all_sorted }
sub init_all_parts     { SL::DB::Manager::Part->get_all_sorted     }
sub init_h_unit_name   { first { SL::DB::Manager::Unit->find_by(name => $_) } qw(Std h Stunde) };

sub load_parts_for_sections {
  my ($self, %params) = @_;

  $self->parts({ map { ($_->{id} => $_) } @{ SL::DB::Manager::Part->get_all(where => [ id => [ uniq map { $_->{order_part_id} } @{ $params{sections} } ] ]) } });
}

sub create_order_item {
  my ($self, %params) = @_;

  my $section         = $params{section};
  my $item            = $params{item} || SL::DB::OrderItem->new;
  my $part            = $self->parts->{ $section->order_part_id };
  my $description     = $section->{keep_description} ? $item->description : $part->description;

  if (!$section->{keep_description}) {
    $description =  '<%fb_number%> <%title%>' unless $description =~ m{<%};
    $description =~ s{<% (.+?) %>}{$section->$1}egx;
  }

  $item->assign_attributes(
    parts_id    => $part->id,
    description => $description,
    qty         => $section->time_estimation * 1,
    unit        => $self->h_unit_name,
    sellprice   => $::form->round_amount($self->requirement_spec->hourly_rate, 2),
    discount    => 0,
    project_id  => $self->requirement_spec->project_id,
  );

  return $item;
}

sub create_order {
  my ($self, %params) = @_;

  $self->load_parts_for_sections(%params);

  my @orderitems = map { $self->create_order_item(section => $_) } @{ $params{sections} };
  my $employee   = SL::DB::Manager::Employee->current;
  my $customer   = SL::DB::Customer->new(id => $::form->{customer_id})->load;
  my $order      = SL::DB::Order->new(
    globalproject_id        => $self->requirement_spec->project_id,
    transdate               => DateTime->today_local,
    reqdate                 => $::form->{quotation} && $customer->payment_id ? $customer->payment->calc_date : undef,
    quotation               => !!$::form->{quotation},
    orderitems              => \@orderitems,
    customer_id             => $customer->id,
    taxincluded             => $customer->taxincluded,
    intnotes                => $customer->notes,
    language_id             => $customer->language_id,
    payment_id              => $customer->payment_id,
    taxzone_id              => $customer->taxzone_id,
    employee_id             => $employee->id,
    salesman_id             => $employee->id,
    transaction_description => $self->requirement_spec->displayable_name,
    currency_id             => $::instance_conf->get_currency_id,
  );

  $order->calculate_prices_and_taxes;

  return $order;
}

1;
