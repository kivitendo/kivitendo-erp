package SL::Controller::PriceRuleMacro;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::PriceRuleMacro;
use SL::DB::Business;
use SL::DB::PartsGroup;
use SL::DB::Pricegroup;
use SL::Locale::String qw(t8);
use SL::Helper::Flash qw(flash_later);
use SL::Presenter;
use SL::ReportGenerator;
use SL::Controller::Helper::GetModels;
use SL::Controller::Helper::ReportGenerator;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw() ],
  'scalar --get_set_init' => [ qw(
    price_rule_macro meta
    all_price_types models
  ) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('add_javascript');

sub action_new {
  my ($self) = @_;

  # stub definition for new rules
  my $rule = SL::DB::PriceRuleMacro->new(
    definition => {
      priority => 3,
      condition => {
        type => 'container_and',
        condition => [],
      },
      action => {
        type => 'action_container_and',
        action => [],,
      }
    }
  );

  $self->price_rule_macro($rule);

  $self->setup_form_action_bar;
  $self->render('price_rule_macro/form', price_rule_macro => $self->price_rule_macro);
}

sub action_load {
  my ($self) = @_;

  $self->price_rule_macro->update_definition;

  if ($::request->type eq 'json') {
    return $self->render(\$self->price_rule_macro->json_definition, { process => 0, type => 'json'});
  } else {
    $self->setup_form_action_bar;
    return $self->render('price_rule_macro/form', price_rule_macro => $self->price_rule_macro);
  }
}

sub action_save {
  my ($self) = @_;

  my $error;
  my ($macro, $new_macro);

  eval {
    $macro     = $self->price_rule_macro;
    $new_macro = $self->from_form;

    my @price_sources;
    my ($keep, $add, $remove);

    if ($macro->id) {
      ($keep, $add, $remove) = $self->reconcile_generated_price_sources($macro, $new_macro);

      # set removes rules to obsolete
      $_->assign_attributes(obsolete => 1, price_rule_macro_id => undef) for @$remove;

      $macro->definition($new_macro->definition);
      $macro->update_from_definition;
    } else {
      $macro = $new_macro;
      ($keep, $add, $remove) = ([], [ $macro->parsed_definition->price_rules ], []);
    }

    $macro->copy_attributes_to_price_rules(@$keep, @$add);

    $macro->db->with_transaction(sub {
      $_->save for @$remove;

      $macro->update_definition;
      $macro->save;
      $macro->load;

      for (@$keep, @$add) {
        $_->price_rule_macro_id($macro->id);
        $_->items($_->items); # male sure rose knows to add the rule items
        $_->save(cascade => 1);
      }
      1;
    }) or do {
      die $macro->db->error;
    }
  } or do {
    $error = $@ // $macro->db->error;
  };

  if ($::request->type eq 'json') {
    if ($error) {
      return $self->render(\SL::JSON::to_json({ error => $error }), { process => 0, type => 'json' });
    } else {
      return $self->render(\SL::JSON::to_json({ id => $macro->id }), { process => 0, type => 'json' });
    }
  } else {
    if ($error) {
      flash_later('error', $error);
    } else {
      flash_later('info', t8('Price Rule saved.'));
    }
    $self->redirect_to(action => 'load', price_rule_macro => { id => $macro->id });
  }
}

sub action_meta {
  my ($self) = @_;

  if ($::request->type eq 'json') {
    my $meta_definition = SL::DB::PriceRuleMacro->create_definition_meta;

    for (keys %$meta_definition) {
      my $entry = $meta_definition->{$_};
      my $request_suffix = $::request->type ne 'html' ? '.' . $::request->type : '';

      if ($entry->{internal_class} && $entry->{internal_class}->can('picker')) {
        $entry->{picker_url} = $self->url_for(action => 'render_picker' . $request_suffix , type => $_);
      }
    }

    return $_[0]->render(\SL::JSON::to_json($meta_definition), { process => 0, type => 'json' });
  } else {
    die "not supported";
  }
}

sub action_add_value {
  my ($self) = @_;

  die 'invalid container id' unless $::form->{container} =~ /^[-\w]+$/;
  die 'invalid type'         unless $::form->{type}      =~ /^\w+$/;
  die 'invalid prefix'       unless $::form->{prefix}    =~ /^[_\w\[\]\.]+$/;

  my $html = $self->render(
    \"[% PROCESS 'price_rule_macro/input_blocks.html' %][% PROCESS condition_$::form->{type}_value_input %]",
    { output => 0 },
    prefix => $::form->{prefix},
  );

  $self
    ->js
    ->insertBefore($html, '#' . $::form->{container})
    ->reinit_widgets
    ->render;
}

sub action_add_element {
  my ($self) = @_;

  my %known_element_classes = (
    condition => 1,
    action    => 1,
  );

  die 'invalid container id'  unless $::form->{container} =~ /^[-\w]+$/;
  die 'invalid type'          unless $::form->{type}      =~ /^\w+$/;
  die 'invalid prefix'        unless $::form->{prefix}    =~ /^[_\w\[\]\.]+$/;
  die 'invalid element_class' unless $known_element_classes{$::form->{element_class}};

  my $html = $self->render(
    \"[% PROCESS 'price_rule_macro/input_blocks.html' %][% PROCESS $::form->{element_class}_element %]",
    { output => 0 },
    prefix => $::form->{prefix},
    item   => SL::PriceRuleMacro::Element->new(type => $::form->{type}),
  );

  $self
    ->js
    ->insertBefore($html, '#' . $::form->{container})
    ->reinit_widgets
    ->render;
}

sub action_list {
  my ($self) = @_;

  $self->make_filter_summary;

  $self->prepare_report;

  $self->report_generator_list_objects(
    report  => $self->{report},
    objects => $self->models->get,
    layout  => !$::form->{inline},
    header  => !$::form->{inline},
    options => {
      action_bar_setup_hook => sub { $self->setup_search_action_bar(report_generator_actions => [ @_ ]) },
    },
  );
}

### internal

sub prepare_report {
  my ($self)      = @_;

  my $callback    = $self->models->get_callback;

  my $report      = SL::ReportGenerator->new(\%::myconfig, $::form);
  $self->{report} = $report;

  my @columns     = qw(name type priority name items);
  my @sortable    = qw(name type priority name notes      );

  my %column_defs = (
    name          => { obj_link => sub { $self->url_for(action => 'load', 'price_rule_macro.id' => $_[0]->id, callback => $callback) } },
    priority      => { sub  => sub { $_[0]->priority_as_text } },
    obsolete      => { sub  => sub { $_[0]->obsolete_as_bool_yn } },
    notes         => { sub  => sub { $_[0]->notes } },
#     items         => { sub  => sub { $_[0]->item_summary } },
  );

  map { $column_defs{$_}->{text} ||= $::locale->text( $self->models->get_sort_spec->{$_}->{title} ) } keys %column_defs;

  $report->set_options(
    std_column_visibility => 1,
    controller_class      => 'PriceRuleMacro',
    output_format         => 'HTML',
    title                 => t8('Price Rules'),
    allow_pdf_export      => !$::form->{inline},
    allow_csv_export      => !$::form->{inline},
  );
  $report->set_columns(%column_defs);
  $report->set_column_order(@columns);
  $report->set_export_options(qw(list filter));
  $report->set_options_from_form;
  $self->models->disable_plugin('paginated') if $report->{options}{output_format} =~ /^(pdf|csv)$/i;
  $self->models->get_models_url_params(sub{ map { $_ => $::form->{$_} } qw(inline) });
  $self->models->set_report_generator_sort_options(report => $report, sortable_columns => \@sortable);
  $report->set_options(
    raw_bottom_info_text  => $self->render('price_rule_macro/report_bottom', { output => 0 }),
    raw_top_info_text     => $self->render('price_rule_macro/report_top', { output => 0 }),
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

#   if ($filter->{has_item_type}) {
#     push @filter_strings, sprintf "%s: %s", t8('Has item type'), join ', ', map {
#       SL::DB::Manager::PriceRuleItem->get_type($_)->{description}
#     } @{ $filter->{has_item_type} || [] };
#   }

  $self->{filter_summary} = join ', ', @filter_strings;
}

# todo: make this clean and in model
sub allowed_elements_for {
  my ($self, $element) = @_;

  [ map [ $_, $self->meta->{$_}{name} ], $element->allowed_elements ]
}

sub reconcile_generated_price_sources {
  my ($self, $old_macro, $new_macro) = @_;

  my @old_rules = $old_macro->price_rules;
  my @new_rules = $new_macro->parsed_definition->price_rules;

  my %new_by_digest = map { $_->digest => $_ } @new_rules;

  my (@keep, @remove, @add);
  for (@old_rules) {
    if ($new_by_digest{$_->digest}) {
      push @keep, $_;
    } else {
      push @remove, $_;
    }
  }
  push @add, values %new_by_digest;

  return (\@keep, \@add, \@remove);
}

sub init_price_rule_macro {
  my ($self) = @_;

  my $price_rule_macro = SL::DB::Manager::PriceRuleMacro->find_by_or_create(id => $::form->{price_rule_macro}{id});
}

sub init_meta {
  SL::DB::PriceRuleMacro->create_definition_meta
}

sub init_all_price_types {
  [ SL::DB::Manager::PriceRule->all_price_types ]
}

sub init_models {
  my ($self) = @_;

  SL::Controller::Helper::GetModels->new(
    controller => $self,
    sorted => {
      name     => t8('Name'),
      type     => t8('Type'),
      priority => t8('Priority'),
      obsolete => t8('Obsolete'),
      digest    => t8('Rule Details'),
    },
  );
}

sub from_form {
  my ($self) = @_;

  # backwards compatibility
  my $json_definition = delete $::form->{price_rule_macro}{json_definition};

  my $obj = SL::DB::PriceRuleMacro->new(definition => $::form->{price_rule_macro});
  $obj->json_definition($json_definition) if $json_definition;

  $obj->update_from_definition;
  $obj->validate;
  $obj;
}

sub setup_form_action_bar {
  my ($self) = @_;

  my $is_new = !$self->price_rule_macro->id;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          submit         => [ 'form', { action => 'PriceRuleMacro/save' } ],
          checks         => [ 'kivi.validate_form' ],
          accesskey      => 'alt+S',
          accesskey_body => 1,
        ],
        action => [
          t8('Use as new'),
          submit   => [ '#form', { action => 'PriceRuleMacro/clone' } ],
          disabled => $is_new ? t8('The object has not been saved yet.') : undef,
        ],
      ], # end of combobox "Save"

      action => [
        t8('Delete'),
        submit   => [ '#form', { action => 'PriceRuleMacro/delete' } ],
        confirm  => t8('Do you really want to delete this object?'),
        disabled => $is_new                   ? t8('The object has not been saved yet.')
                  : $self->price_rule_macro->in_use ? t8('This object has already been used.')
                  :                             undef,
      ],

      link => [
        t8('Abort'),
        link => $self->url_for(action => 'list', 'filter.type' => $self->price_rule_macro->type),
      ],
    );
  }
}

sub setup_search_action_bar {
  my ($self, %params) = @_;

  return if $::form->{inline};

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      action => [
        t8('Update'),
        submit    => [ '#search_form', { action => 'PriceRuleMacro/list' } ],
        accesskey => 'enter',
        checks    => [ [ 'kivi.validate_form', '#search_form' ] ],
      ],

      'separator',

      @{ $params{report_generator_actions} },

      combobox => [
        action => [
          t8('Add'),
        ],
        link => [
          t8('New Sales Price Rule'),
          link => $self->url_for(action => 'new', 'price_rule_macro.type' => 'customer', callback => $self->models->get_callback),
        ],
        link => [
          t8('New Purchase Price Rule'),
          link => $self->url_for(action => 'new', 'price_rule_macro.type' => 'vendor', callback => $self->models->get_callback),
        ],
      ], # end of combobox "Add"
    );
  }
}

sub check_auth {
  $::auth->assert('price_rules');
}

sub add_javascript {
  $::request->layout->add_javascripts('kivi.PriceRuleMacro.js');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Controller::PriceRuleMacro - controller for price rule macros

=head1 ACTIONS

=over 4

=item * C<load>

=item * C<save>

=item * C<meta>

=back

=head1 HOW TO ADD NEW PROPERTIES

If you want to extend this with new elements, here's a list to do:

* If it's a totally new condition or action, make first sure the underlying price rules can handle that. See there

* Add a class for it in SL::DB::PriceRuleMacro. Make sure it has:
  - the right base class
  - a type
  - elements
  - a rule to generate price_rules or price_rule_items
  - array_elements
  - validate
  - a description

* Register the class with their type also in SL::DB::PriceRuleMacro

* Add a block for it in input_blocks. Make sure to get right:
  - the remove controls (by having it sit in a element div)
  - prefixes (for round trips)


=head1 BUGS

None yet :)

=head1 TODO

- functionality:
   actions
   save/roundtrip
   new/create
   cloning
   doc for adding rule types, macro blocks
   fix help popups
   menu entries

- styling:
    fieldset styling, interactive styling
    add hover effects
    spacing

- robustness:
   id not in json
   fix itime/mtime crap
   all inputs to presenter
   safety to not remove last elements in array_elements and in condition/action?
   deduplication
   make all number inputs numeric/validate
   fix compile warning in ubuntu 14.04, perl 5.18.2

- polish:
   multiple actions/ action-macros / typed actions
   typeless container add
   keyboard shortcuts for table-like controls and to extend multiples
   optional: controles to convert IdCondition to conditionalaction (ex.: convert parts list to partspriceaction)
   item_summary for automated description
   generated price rules in second tab
   titles for new/edit

=head1 AUTHOR

Sven Schöling E<lt>sven.schoeling@opendynamic.deE<gt>

=cut

