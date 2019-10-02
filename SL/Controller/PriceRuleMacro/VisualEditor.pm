package SL::Controller::PriceRuleMacro::VisualEditor;

use strict;
use parent qw(Rose::Object);

use Scalar::Util qw(weaken);
use SL::Locale::String qw(t8);
use SL::DB::PriceRuleMacro;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw() ],
  'scalar --get_set_init' => [ qw(
    price_rule_macro meta
  ) ],
);

# for multi value elements with exactly one sub element. just name the block like their only accessible field
sub action_add_line {
  my ($self) = @_;

  die 'invalid container id' unless $::form->{container} =~ /^[-\w]+$/;
  die 'invalid type'         unless $::form->{type}      =~ /^\w+$/;
  die 'invalid prefix'       unless $::form->{prefix}    =~ /^[_\w\[\]\.]+$/;

  my $meta = $self->controller->meta->{$::form->{type}} or die "unknown type $::form->{type}";

  my @array_elements = grep {
    $self->controller->meta->{$_}
  } $meta->{internal_class}->array_elements;

  my $parent = $meta->{internal_class}->new(%{ $::form->{parent} // {} });

  die "type $::form->{type} does not have exactly one array element" unless 1 == scalar @array_elements;

  my $html = $self->controller->render(
    \"[% PROCESS 'price_rule_macro/visual_editor/input_blocks.html' %][% PROCESS @{array_elements}_input %]",
    { output => 0 },
    prefix => $::form->{prefix},
    item => SL::PriceRuleMacro::Element->new(type => @array_elements),
    parent => $parent,
  );

  $self->controller
    ->js
    ->insertBefore($html, '#' . $::form->{container})
    ->reinit_widgets
    ->render;
}

sub action_add_value {
  my ($self) = @_;

  die 'invalid container id' unless $::form->{container} =~ /^[-\w]+$/;
  die 'invalid type'         unless $::form->{type}      =~ /^\w+$/;
  die 'invalid prefix'       unless $::form->{prefix}    =~ /^[_\w\[\]\.]+$/;

  my $html = $self->controller->render(
    \"[% PROCESS 'price_rule_macro/visual_editor/input_blocks.html' %][% PROCESS condition_$::form->{type}_value_input %]",
    { output => 0 },
    prefix => $::form->{prefix},
  );

  $self->controller
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

  my $html = $self->controller->render(
    \"[% PROCESS 'price_rule_macro/visual_editor/input_blocks.html' %][% PROCESS $::form->{element_class}_element %]",
    { output => 0 },
    prefix => $::form->{prefix},
    item   => SL::PriceRuleMacro::Element->new(type => $::form->{type}),
  );

  $self->controller
    ->js
    ->insertBefore($html, '#' . $::form->{container})
    ->reinit_widgets
    ->render;
}

sub action_replace_element {
  my ($self) = @_;

  my %known_element_classes = (
    condition => 1,
    action    => 1,
  );

  die 'invalid container id'  unless $::form->{container} =~ /^[-\w]+$/;
  die 'invalid type'          unless $::form->{type}      =~ /^\w+$/;
  die 'invalid prefix'        unless $::form->{prefix}    =~ /^[_\w\[\]\.]+$/;
  die 'invalid element_class' unless $known_element_classes{$::form->{element_class}};

  my $html = $self->controller->render(
    \"[% PROCESS 'price_rule_macro/visual_editor/input_blocks.html' %][% PROCESS $::form->{element_class}_element %]",
    { output => 0 },
    prefix => $::form->{prefix},
    item   => SL::PriceRuleMacro::Element->new(type => $::form->{type}, %{ $::form->{params} // {} }),
  );

  $self->controller
    ->js
    ->replaceWith('#' . $::form->{container}, $html)
    ->reinit_widgets
    ->render;
}

sub render_form {
  my ($self) = @_;
  $self->controller->render('price_rule_macro/visual_editor/form', price_rule_macro => $self->controller->price_rule_macro);
}

sub empty_price_rule_macro {
  SL::DB::PriceRuleMacro->new(
    definition => {
      priority => 3,
      action => {
        type => 'action_container_and',
        action => [
          {
            type => 'conditional_action',
            condition => [  ],
            action => [  ],
          }
        ],
      },
      format_version => SL::DB::PriceRuleMacro->latest_version,
    }
  );
}

sub controller {
  if (@_ > 1) {
    weaken($_[0]{controller} = $_[1]);
  }

  $_[0]{controller};
}

1;
