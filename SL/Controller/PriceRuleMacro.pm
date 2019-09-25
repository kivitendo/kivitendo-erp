package SL::Controller::PriceRuleMacro;

use strict;
use parent qw(SL::Controller::Base);

use SL::DB::PriceRuleMacro;
use SL::Locale::String qw(t8);
use SL::Helper::Flash qw(flash flash_later);
use SL::Controller::PriceRuleMacro::Report;
use SL::Controller::PriceRuleMacro::FullEditor;
use SL::Controller::Helper::ReportGenerator ();

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw() ],
  'scalar --get_set_init' => [ qw(
    price_rule_macro meta
    all_price_types
    report editor
  ) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('add_javascript');

use SL::Helper::Object (
  delegate => [
    report => [ qw(action_list), @SL::Controller::Helper::ReportGenerator::EXPORT ],
    editor => [ qw(empty_price_rule_macro render_form action_add_line action_add_value action_add_element) ],
  ],
);

sub action_new {
  my ($self) = @_;

  $self->price_rule_macro($self->empty_price_rule_macro);
  $self->setup_form_action_bar;
  $self->render_form;
}

sub action_load {
  my ($self) = @_;

  $self->price_rule_macro->update_definition;

  if ($::request->type eq 'json') {
    $self->render(\$self->price_rule_macro->json_definition, { process => 0, type => 'json'});
  } else {
    $self->setup_form_action_bar;
    $self->render_form
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
      flash('error', $error);
      $self->price_rule_macro($macro);
      $self->action_load;
    } else {
      flash_later('info', t8('Price Rule saved.'));
      $self->redirect_to(action => 'load', price_rule_macro => { id => $macro->id });
    }
  }
}

sub action_clone {
  my ($self) = @_;

  $self->price_rule_macro;
  $self->price_rule_macro->id(undef);

  $self->setup_form_action_bar;
  $self->render_form;
}

sub action_delete {
  my ($self) = @_;

  $self->price_rule_macro->delete;
  flash_later('info',  t8('The price rule has been deleted.'));

  $self->redirect_to($::form->{callback} || (action => 'list'));
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

### internal

# todo: make this clean and in model/presenter
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

  my $price_rule_macro = SL::DB::Manager::PriceRuleMacro->find_by_or_create(id => $::form->{price_rule_macro}{id} || 0);
}

sub init_report {
  SL::Controller::PriceRuleMacro::Report->new(controller => $_[0]);
}

sub init_editor {
  SL::Controller::PriceRuleMacro::FullEditor->new(controller => $_[0]);
}

sub init_meta {
  SL::DB::PriceRuleMacro->create_definition_meta
}

sub init_all_price_types {
  [ SL::DB::Manager::PriceRule->all_price_types ]
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
          submit   => [ 'form', { action => 'PriceRuleMacro/clone' } ],
          disabled => $is_new ? t8('The object has not been saved yet.') : undef,
        ],
      ], # end of combobox "Save"

      action => [
        t8('Delete'),
        submit   => [ 'form', { action => 'PriceRuleMacro/delete' } ],
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

sub check_auth {
  $::auth->assert('price_rules');
}

sub add_javascript {
  $::request->layout->add_javascripts(qw(kivi.PriceRuleMacro.js kivi.CustomerVendor.js kivi.Part.js));
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
  - prefixes (for round trips) - ATTENTION, format differs between conditions and actions, be careful

* If the internal format of existing definitions changes, make sure that the
  old ones still work by adding an upgrade hook in SL::DB::PriceRuleMacro

=head1 BUGS

None yet :)

=head1 TODO

- functionality:
   fix help popups
   conditional action

- styling:
    fieldset styling, interactive styling
    add hover effects
    spacing

- robustness:
   all inputs to presenter
   safety to not remove last elements in array_elements and in condition/action?
   safety to not submit/save without condition/action
   deduplication
   make new_empty accessor to fill container initially

- polish:
   typed actions
   typeless container add
   keyboard shortcuts for table-like controls and to extend multiples
   optional: controles to convert IdCondition to conditionalaction (ex.: convert parts list to partspriceaction)
   item_summary for automated description
   generated price rules in second tab
   titles for new/edit

=head1 AUTHOR

Sven Schöling E<lt>sven.schoeling@opendynamic.deE<gt>

=cut

