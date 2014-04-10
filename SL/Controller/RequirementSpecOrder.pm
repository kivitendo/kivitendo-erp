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

use constant LIST_SELECTOR  => '#quotations_and_orders';
use constant FORMS_SELECTOR => '#quotations_and_orders_article_assignment,#quotations_and_orders_new,#quotations_and_orders_update';

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(parts) ],
  'scalar --get_set_init' => [ qw(requirement_spec rs_order js h_unit_name all_customers all_parts_time_unit) ],
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

  if (!@{ $self->all_parts_time_unit }) {
    return $self->js->flash('error', t8('This function requires the presence of articles with a time-based unit such as "h" or "min".'))->render($self);
  }

  my $html = $self->render('requirement_spec_order/new', { output => 0 }, make_part_title => sub { $_[0]->partnumber . ' ' . $_[0]->description });
  $self->js->hide(LIST_SELECTOR())
           ->after(LIST_SELECTOR(), $html)
           ->render($self);
}

sub action_create {
  my ($self)         = @_;

  if (!$::auth->assert($::form->{quotation} ? 'sales_quotation_edit' : 'sales_order_edit', 1)) {
    return $self->js->flash('error', t8("You do not have the permissions to access this function."))->render($self);
  }

  # 1. Update sections with selected part IDs.
  my $section_attrs  = $::form->{sections} || [];
  my $sections       = SL::DB::Manager::RequirementSpecItem->get_all_sorted(where => [ id => [ map { $_->{id} } @{ $section_attrs } ] ]);
  my %sections_by_id = map { ($_->{id} => $_) } @{ $sections };

  $sections_by_id{ $_->{id} }->update_attributes(order_part_id => $_->{order_part_id}) for @{ $section_attrs };

  # 2. Create actual quotation/order.
  my $order = $self->create_order(sections => $sections);
  $order->db->with_transaction(sub {
    $order->save;

    $self->requirement_spec->orders(
      @{ $self->requirement_spec->orders },
      SL::DB::RequirementSpecOrder->new(order => $order, version => $self->requirement_spec->version)
    );
    $self->requirement_spec->save;

    $self->requirement_spec->link_to_record($order);
  }) or do {
    $::lxdebug->message(LXDebug::WARN(), "Error creating the order object: $@");
  };

  $self->init_requirement_spec;

  # 3. Notify the user and return to list.
  my $html = $self->render('requirement_spec_order/list', { output => 0 });
  $self->js->replaceWith(LIST_SELECTOR(), $html)
           ->remove(FORMS_SELECTOR())
           ->flash('info', $::form->{quotation} ? t8('Sales quotation #1 has been created.', $order->quonumber) : t8('Sales order #1 has been created.', $order->ordnumber))
           ->render($self);
}

sub action_update {
  my ($self)   = @_;

  my $order    = $self->rs_order->order;
  my $sections = $self->requirement_spec->sections_sorted;

  if (!$::auth->assert($order->quotation ? 'sales_quotation_edit' : 'sales_order_edit', 1)) {
    return $self->js->flash('error', t8("You do not have the permissions to access this function."))->render($self);
  }

  my (@orderitems, %sections_seen);
  foreach my $item (@{ $order->items_sorted }) {
    my $section = first { my $num = $_->fb_number; $item->description =~ m{\b\Q${num}\E\b} && !$sections_seen{ $_->id } } @{ $sections };

    $sections_seen{ $section->id } = 1 if $section;

    push @orderitems, { item => $item, section => $section };
  }

  my $html = $self->render(
    'requirement_spec_order/update', { output => 0 },
    orderitems         => \@orderitems,
    sections           => $sections,
    make_section_title => sub { $_[0]->fb_number . ' ' . $_[0]->title },
  );

  $self->js->hide(LIST_SELECTOR())
           ->after(LIST_SELECTOR(), $html)
           ->render($self);
}

sub action_do_update {
  my ($self)           = @_;

  my $order            = $self->rs_order->order;
  my $sections         = $self->requirement_spec->sections_sorted;
  my %orderitems_by_id = map { ($_->id => $_) } @{ $order->orderitems };
  my %sections_by_id   = map { ($_->id => $_) } @{ $sections };
  $self->{parts}       = { map { ($_->id => $_) } @{ SL::DB::Manager::Part->get_all(where => [ id => [ uniq map { $_->order_part_id } @{ $sections } ] ]) } };
  my $language_id      = $self->requirement_spec->customer->language_id;

  my %sections_seen;

  foreach my $attributes (@{ $::form->{orderitems} || [] }) {
    my $orderitem = $orderitems_by_id{ $attributes->{id}         };
    my $section   = $sections_by_id{   $attributes->{section_id} };
    next unless $orderitem && $section;

    $self->create_order_item(section => $section, item => $orderitem, language_id => $language_id)->save;
    $sections_seen{ $section->id } = 1;
  }

  my @new_orderitems = map  { $self->create_order_item(section => $_, language_id => $language_id) }
                       grep { !$sections_seen{ $_->id } }
                       @{ $sections };

  $order->orderitems([ @{ $order->orderitems }, @new_orderitems ]) if @new_orderitems;

  $order->calculate_prices_and_taxes;

  $order->db->with_transaction(sub {
    $order->save;
    $self->requirement_spec->link_to_record($order);
  }) or do {
    $::lxdebug->message(LXDebug::WARN(), "Error updating the order object: $@");
  };

  $self->init_requirement_spec;

  my $html = $self->render('requirement_spec_order/list', { output => 0 });
  $self->js->replaceWith(LIST_SELECTOR(), $html)
           ->remove(FORMS_SELECTOR())
           ->flash('info', $::form->{quotation} ? t8('Sales quotation #1 has been updated.', $order->quonumber) : t8('Sales order #1 has been updated.', $order->ordnumber))
           ->render($self);
}

sub action_edit_assignment {
  my ($self) = @_;

  if (!@{ $self->all_parts_time_unit }) {
    return $self->js->flash('error', t8('This function requires the presence of articles with a time-based unit such as "h" or "min".'))->render($self);
  }

  my $html   = $self->render('requirement_spec_order/edit_assignment', { output => 0 }, make_part_title => sub { $_[0]->partnumber . ' ' . $_[0]->description });
  $self->js->hide(LIST_SELECTOR())
           ->after(LIST_SELECTOR(), $html)
           ->render($self);
}

sub action_save_assignment {
  my ($self)   = @_;
  my $sections = $::form->{sections} || [];
  SL::DB::RequirementSpecItem->new(id => $_->{id})->load->update_attributes(order_part_id => ($_->{order_part_id} || undef)) for @{ $sections };

  my $html = $self->render('requirement_spec_order/list', { output => 0 });
  $self->js->replaceWith(LIST_SELECTOR(), $html)
           ->remove(FORMS_SELECTOR())
           ->render($self);
}

sub action_delete {
  my ($self) = @_;

  my $order  = $self->rs_order->order;

  $order->delete;
  $self->init_requirement_spec;

  my $html = $self->render('requirement_spec_order/list', { output => 0 });
  $self->js->replaceWith(LIST_SELECTOR(), $html)
           ->flash('info', $order->quotation ? t8('Sales quotation #1 has been deleted.', $order->quonumber) : t8('Sales order #1 has been deleted.', $order->ordnumber))
           ->render($self);
}

#
# filters
#

sub setup {
  my ($self) = @_;

  $::auth->assert('requirement_spec_edit');
  $::request->{layout}->use_stylesheet("${_}.css") for qw(jquery.contextMenu requirement_spec autocomplete_part);
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

sub init_all_customers { SL::DB::Manager::Customer->get_all_sorted }
sub init_h_unit_name   { first { SL::DB::Manager::Unit->find_by(name => $_) } qw(Std h Stunde) };
sub init_rs_order      { SL::DB::RequirementSpecOrder->new(id => $::form->{rs_order_id})->load };

sub init_all_parts_time_unit {
  my ($self) = @_;

  return [] unless $self->h_unit_name;

  my @convertible_unit_names = map { $_->name } @{ SL::DB::Manager::Unit->find_by(name => $self->h_unit_name)->convertible_units };

  return SL::DB::Manager::Part->get_all_sorted(where => [ unit => \@convertible_unit_names ]);
}

#
# helpers
#

sub load_parts_for_sections {
  my ($self, %params) = @_;

}

sub create_order_item {
  my ($self, %params) = @_;

  my $section         = $params{section};
  my $item            = $params{item} || SL::DB::OrderItem->new;
  my $part            = $self->parts->{ $section->order_part_id };
  my $translation     = $params{language_id} ? first { $params{language_id} == $_->language_id } @{ $part->translations } : {};
  my $description     = $section->{keep_description} ? $item->description : ($translation->{translation} || $part->description);
  my $longdescription = $translation->{longdescription} || $part->notes;

  if (!$section->{keep_description}) {
    $description     = '<%fb_number%> <%title%>' unless $description =~ m{<%};
    $longdescription = '&lt;%description%&gt;'   unless $longdescription =~ m{&lt;%};

    $description     =~ s{<% (.+?) %>}{ $section->can($1) ? $section->$1 : '<' . t8('Invalid variable #1', $1) . '>' }egx;
    $longdescription =~ s{\&lt;\% description \%\&gt;}{!!!!DESCRIPTION!!!!}gx;
    $longdescription =~ s{<[pP]> !!!!DESCRIPTION!!!! </[pP]>}{!!!!DESCRIPTION!!!!}gx;
    $longdescription =~ s{\&lt;\% (.+?) \%\&gt;}{ $section->can($1) ? $::locale->quote_special_chars('HTML', $section->$1 // '') : '<' . t8('Invalid variable #1', $1) . '>' }egx;
    $longdescription =~ s{!!!!DESCRIPTION!!!!}{ $section->description // '' }egx;
  }

  $item->assign_attributes(
    parts_id        => $part->id,
    description     => $description,
    longdescription => $longdescription,
    qty             => $section->time_estimation * 1,
    unit            => $self->h_unit_name,
    sellprice       => $::form->round_amount($self->requirement_spec->hourly_rate, 2),
    lastcost        => $part->lastcost,
    discount        => 0,
    project_id      => $self->requirement_spec->project_id,
  );

  return $item;
}

sub create_order {
  my ($self, %params) = @_;

  $self->{parts} = { map { ($_->{id} => $_) } @{ SL::DB::Manager::Part->get_all(where => [ id => [ uniq map { $_->{order_part_id} } @{ $params{sections} } ] ]) } };

  my $customer   = SL::DB::Customer->new(id => $::form->{customer_id})->load;
  my @orderitems = map { $self->create_order_item(section => $_, language_id => $customer->language_id) } @{ $params{sections} };
  my $employee   = SL::DB::Manager::Employee->current;
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
