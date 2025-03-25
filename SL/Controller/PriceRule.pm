package SL::Controller::PriceRule;

use strict;

use parent qw(SL::Controller::Base);

use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ParseFilter;
use SL::Controller::Helper::ReportGenerator;
use SL::DB::PriceRule;
use SL::DB::PriceRuleItem;
use SL::DB::Pricegroup;
use SL::DB::PartsGroup;
use SL::DB::Business;
use SL::Helper::Flash;
use SL::Locale::String;

use Rose::Object::MakeMethods::Generic
(
 'scalar --get_set_init' => [ qw(models price_rule vc pricegroups partsgroups businesses cvar_configs) ],
);

# __PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('add_javascripts');

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->make_filter_summary;

  my $price_rules = $self->models->get;

  $self->setup_search_action_bar;

  $self->prepare_report;

  $self->report_generator_list_objects(report => $self->{report}, objects => $price_rules, $::form->{inline} ? (layout => 0, header => 0) : ());
}

sub action_new {
  my ($self) = @_;

  $self->price_rule(SL::DB::PriceRule->new);
  $self->price_rule->assign_attributes(%{ $::form->{price_rule} || {} });
  $self->display_form;
}

sub action_edit {
  my ($self) = @_;

  $self->display_form;
}

sub action_create {
  my ($self) = @_;

  $self->price_rule($self->price_rule->clone_and_reset_deep);
  $self->create_or_update;
}

sub action_update {
  my ($self) = @_;
  $self->create_or_update;
}

 #TODO
sub action_destroy {
  my ($self) = @_;

  $self->price_rule->delete;
  flash_later('info',  $::locale->text('The price rule has been deleted.'));

  $self->redirect_to($::form->{callback} || (action => 'list'));
}

sub action_add_item_row {
  my ($self, %params) = @_;

  my $item = $::form->{type} =~ m{cvar/(\d+)}
    ? SL::DB::PriceRuleItem->new(type => 'cvar', custom_variable_configs_id => $1)
    : SL::DB::PriceRuleItem->new(type => $::form->{type});

  my $html = $self->render('price_rule/item', { output => 0 }, item => $item);

  $self
    ->js
    ->before('#price_rule_new_items', $html)
    ->reinit_widgets
    ->render;
}

sub action_price_type_help {
  $_[0]->render('price_rule/price_type_help', { layout => 0 });
}

#
# filters
#

sub check_auth {
  $::auth->assert('price_rule_edit');
}

#
# helpers
#

sub display_form {
  my ($self, %params) = @_;
  my $is_new  = !$self->price_rule->id;
  my $title   = $self->form_title(($is_new ? 'create' : 'edit'), $self->price_rule->type);
  $self->setup_form_action_bar;
  $self->render('price_rule/form',
    title => $title,
    %params
  );
}

sub form_title {
  my ($self, $action, $type) = @_;

  return {
    edit => {
      customer => t8('Edit sales price rule'),
      vendor   => t8('Edit purchase price rule'),
      ''       => t8('Edit price rule'),
    },
    create => {
      customer => t8('Create a new sales price rule'),
      vendor   => t8('Create a new purchase price rule'),
      ''       => t8('Create a new price rule'),
    },
    list => {
      customer => t8('Sales Price Rules'),
      vendor   => t8('Purchase Price Rules'),
      ''       => t8('Price Rules'),
    },
  }->{$action}{$type};
}

sub create_or_update {
  my $self   = shift;
  my $is_new = !$self->price_rule->id;
  my $params = delete($::form->{price_rule}) || { };

  delete $params->{id};
  $self->price_rule->assign_attributes(%{ $params });

  my @errors = $self->price_rule->validate;

  if (@errors) {
    flash('error', $_) for @errors;
    $self->display_form(callback => $::form->{callback});
    return;
  }

  $self->price_rule->save;

  flash_later('info', $is_new ? $::locale->text('The price rule has been created.') : $::locale->text('The price rule has been saved.'));

  $self->redirect_to($::form->{callback} || (action => 'list', 'filter.type' => $self->price_rule->type));
}

sub prepare_report {
  my ($self)      = @_;

  my $callback    = $self->models->get_callback;

  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns     = qw(name type priority price reduction discount items);
  my @sortable    = qw(name type priority price reduction discount      );

  my %column_defs = (
    name          => { obj_link => sub { $self->url_for(action => 'edit', 'price_rule.id' => $_[0]->id, callback => $callback) } },
    priority      => { sub  => sub { $_[0]->priority_as_text } },
    price         => { sub  => sub { $_[0]->price_as_number } },
    reduction     => { sub  => sub { $_[0]->reduction_as_number } },
    discount      => { sub  => sub { $_[0]->discount_as_number } },
    obsolete      => { sub  => sub { $_[0]->obsolete_as_bool_yn } },
    items         => { sub  => sub { $_[0]->item_summary } },
  );

  map { $column_defs{$_}->{text} ||= $::locale->text( $self->models->get_sort_spec->{$_}->{title} ) } keys %column_defs;

  if ( $report->{options}{output_format} =~ /^(pdf|csv)$/i ) {
    $self->models->disable_plugin('paginated');
  }

  my $title        = t8('Price Rules');
  $report->{title} = $title; #for browser titlebar (title-tag)

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'PriceRule',
    output_format         => 'HTML',
    title                 => $self->form_title('list', $self->vc),
    allow_pdf_export      => !$::form->{inline},
    allow_csv_export      => !$::form->{inline},
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter));
  $report->set_options_from_form;
  $self->models->get_models_url_params(sub{ map { $_ => $::form->{$_} } qw(inline) });
  $self->models->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);
  $report->set_options(
    raw_bottom_info_text  => $self->render('price_rule/report_bottom', { output => 0 }),
    raw_top_info_text     => $self->render('price_rule/report_top', { output => 0 }),
  );
}

sub make_filter_summary {
  my ($self) = @_;

  my $filter = $::form->{filter} || {};
  my @filter_strings;

  my @filters = (
    [ $filter->{"name:substr::ilike"}, t8('Name')  ],
    [ $filter->{"price:number"},       t8('Price') ],
    [ $filter->{"discount:number"},    t8('Discount') ],
  );

  for (@filters) {
    push @filter_strings, "$_->[1]: $_->[0]" if $_->[0];
  }

  if ($filter->{has_item_type}) {
    push @filter_strings, sprintf "%s: %s", t8('Has item type'), join ', ', map {
      SL::DB::Manager::PriceRuleItem->get_type($_)->{description}
    } @{ $filter->{has_item_type} || [] };
  }

  $self->{filter_summary} = join ', ', @filter_strings;
}

sub all_price_rule_item_types {
  my $item_types = SL::DB::Manager::PriceRuleItem->get_all_types($_[0]->vc || $_[0]->price_rule->type);
  my @cvar_types = map [ "cvar/" . $_->id, $_->presenter->description_with_module ], @{$_[0]->cvar_configs };

  [ @$item_types, @cvar_types ];
}

sub add_javascripts  {
  $::request->{layout}->add_javascripts(qw(kivi.PriceRule.js autocomplete_vendor.js kivi.Part.js kivi.CustomerVendor.js));
}

sub init_price_rule {
  my ($self) = @_;

  my $price_rule = $::form->{price_rule}{id} ? SL::DB::PriceRule->new(id => $::form->{price_rule}{id})->load : SL::DB::PriceRule->new;

  my $items = delete $::form->{price_rule}{items};

  $price_rule->assign_attributes(%{ $::form->{price_rule} || {} });

  my %old_items = map { $_->id => $_ } $price_rule->items;

  my @items;
  for my $raw_item (@$items) {
    my $item = $raw_item->{id}
      ? $old_items{ $raw_item->{id} } || SL::DB::PriceRuleItem->new(id => $raw_item->{id})->load
      : SL::DB::PriceRuleItem->new;
    $item->assign_attributes(%$raw_item);
    push @items, $item;
  }

  $price_rule->items(@items) if @items;

  $self->price_rule($price_rule);
}

sub init_vc {
  $::form->{filter}{type};
}

sub init_businesses {
  SL::DB::Manager::Business->get_all;
}

sub init_pricegroups {
  SL::DB::Manager::Pricegroup->get_all_sorted;
}

sub init_partsgroups {
  SL::DB::Manager::PartsGroup->get_all;
}

sub init_cvar_configs {
  # eligible cvars for this are all that are reachable from a record or recorditem (all modules but requirement spec)
  # and of a type that price rules support (currently: id-based with picker, numeric or date) and by special request select
  SL::DB::Manager::CustomVariableConfig->get_all(where => [
    "!module" => 'RequirementSpecs',
    type => [ qw(timestamp date number integer customer vendor part select) ],
  ]) ;
}


sub all_price_types {
  SL::DB::Manager::PriceRule->all_price_types;
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    sorted => {
      name     => t8('Name'),
      type     => t8('Type'),
      priority => t8('Priority'),
      price    => t8('Price'),
      discount => t8('Discount'),
      reduction => t8('Reduced Master Data'),
      obsolete => t8('Obsolete'),
      items    => t8('Rule Details'),
    },
  );
}

sub setup_search_action_bar {
  my ($self, %params) = @_;

  return if $::form->{inline};

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#search_form', { action => 'PriceRule/list' } ],
        accesskey => 'enter',
      ],

      combobox => [
        action => [
          t8('Add'),
        ],
        link => [
          t8('New Sales Price Rule'),
          link => $self->url_for(action => 'new', 'price_rule.type' => 'customer', callback => $self->models->get_callback),
        ],
        link => [
          t8('New Purchase Price Rule'),
          link => $self->url_for(action => 'new', 'price_rule.type' => 'vendor', callback => $self->models->get_callback),
        ],
      ], # end of combobox "Add"
    );
  }
}

sub setup_form_action_bar {
  my ($self) = @_;

  my $is_new = !$self->price_rule->id;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          $is_new ? t8('Create') : t8('Save'),
          submit    => [ '#form', { action => 'PriceRule/' . ($is_new ? 'create' : 'update') } ],
          accesskey => 'enter',
        ],
        action => [
          t8('Use as new'),
          submit   => [ '#form', { action => 'PriceRule/create' } ],
          disabled => $is_new ? t8('The object has not been saved yet.') : undef,
        ],
      ], # end of combobox "Save"

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => 'PriceRule/destroy' } ],
        confirm  => t8('Do you really want to delete this object?'),
        disabled => $is_new                   ? t8('The object has not been saved yet.')
                  : $self->price_rule->in_use ? t8('This object has already been used.')
                  :                             undef,
      ],

      link => [
        t8('Abort'),
        link => $self->url_for(action => 'list', 'filter.type' => $self->price_rule->type),
      ],
    );
  }
}

1;
