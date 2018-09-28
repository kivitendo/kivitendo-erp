# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::PriceRuleMacro;

use strict;

use SL::DB::MetaSetup::PriceRuleMacro;
use SL::DB::Manager::PriceRuleMacro;
use SL::MoreCommon;

__PACKAGE__->meta->add_relationship(
  price_rules => {
    type         => 'one to many',
    class        => 'SL::DB::PriceRule',
    column_map   => { 'id' => 'price_rule_macro_id' },
  },
);

__PACKAGE__->meta->initialize;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(parsed_definition) ],
);

sub definition {
  my ($self, $data) = @_;
  $self->json_definition(SL::JSON::to_json($data)) if $data;
  SL::JSON::from_json($self->json_definition);
}

sub update_definition {
  my ($self, $data) = @_;
  $self->definition->{$_} = $self->$_ for qw(name priority obsolete type);
  $self->definition($self->definition);
}

sub copy_attributes_to_price_rules {
  my ($self, @price_rules) = @_;

  for (@price_rules) {
    $_->assign_attributes(
      name     => $self->name,
      obsolete => $self->obsolete,
      priority => $self->priority,
      type     => $self->type,
    );
  }
}

sub init_parsed_definition {
  die 'definition does not seem to be a json object' unless 'HASH' eq ref($_[0]->definition);
  SL::PriceRuleMacro::Definition->new(%{ $_[0]->definition });
}


# some helper classes, maybe put them into their own files later
my %classes = (
  condition             => 'SL::PriceRuleMacro::Condition',
  container_and         => 'SL::PriceRuleMacro::Condition::ContainerAnd',
  container_or          => 'SL::PriceRuleMacro::Condition::ContainerOr',
  customer              => 'SL::PriceRuleMacro::Condition::Customer',
  vendor                => 'SL::PriceRuleMacro::Condition::Vendor',
  business              => 'SL::PriceRuleMacro::Condition::Business',
  part                  => 'SL::PriceRuleMacro::Condition::Part',
  partsgroup            => 'SL::PriceRuleMacro::Condition::Partsgroup',
  qty                   => 'SL::PriceRuleMacro::Condition::Qty',
  qty_range             => 'SL::PriceRuleMacro::Condition::QtyRange',
  reqdate               => 'SL::PriceRuleMacro::Condition::Reqdate',
  transdate             => 'SL::PriceRuleMacro::Condition::Transdate',
  action                => 'SL::PriceRuleMacro::Action',
  conditional_action    => 'SL::PriceRuleMacro::ConditionalAction',
  simple_action         => 'SL::PriceRuleMacro::Action::Simple',
  price_scale_action    => 'SL::PriceRuleMacro::Action::PriceScale',
  customer_group_action => 'SL::PriceRuleMacro::Action::CustomerGroup',
);
my %r_classes = reverse %classes;

package SL::PriceRuleMacro::Element {
  sub new {
    my $class = shift;
    my %args  = @_;

    if ($args{type}) {
      if ($classes{$args{type}} && $classes{$args{type}}->isa($class)) {
        my $new_class = $classes{delete $args{type}};
        return $new_class->new(%args);
      } else {
        die "type $args{type} not allowed in $class";
      }
    }

    my $self = bless {}, $class;

    while (@_) {
      my $method = shift;
      my $value  = shift;
      if ($class->can($method)) {
        my $type = $classes{$method};
        if ($type) {
          if ('ARRAY' eq ref $value) {
            $self->$method([ map { $type->new(%$_) } @$value ]);
          } else {
            $self->$method($type->new(%$value));
          }
        } else {
          $self->$method($value);
        }
      } else {
        die "format error: $method is not accepted in $class";
      }
    }
    $self;
  }

  sub elements {
    die 'needs to be implemented';
  }

  sub as_tree {
    my ($self, $slot) = @_;

    my $obj = {};

    for my $method ($self->elements) {
      my $val = $self->$method;
      my $ref;

      next unless defined $val;

      if ('ARRAY' eq ref $val) {
        $ref = [ map { $_->as_tree($method) } @$val ];
      } elsif (ref $val) {
        $ref = $val->as_tree($method);
      } else {
        $ref = $val;
      }
      $obj->{$method} = $ref;
    }

    if ($slot && $slot ne $self->type) {
      $obj->{type} = $self->type;
    }

    $obj;
  }
}

package SL::PriceRuleMacro::Definition {
  our @ISA      = ('SL::PriceRuleMacro::Element');
  my @elements  = (qw(condition action name priority obsolete format_version));

  Rose::Object::MakeMethods::Generic->make_methods(
    scalar => [@elements]
  );

  sub elements {
    @elements
  }

  sub cross (&\@\@) {
    my ($code, $x, $y) = @_;
    map {
      my $s = $_;
      map {
        $code->(local $a = $_, local $b = $s);
      } @$x
    } @$y;
  }

  sub price_rules {
    my ($self) = @_;
    my @price_rules = map { $_->price_rules } SL::MoreCommon::listify($self->action);
    my @items       = map { $_->price_rule_items } SL::MoreCommon::listify($self->condition);

    cross {
      my ($price_rule, $item_set) = @_;
      my $new_rule = $_->clone_and_reset;
      my @items = map { $_->clone_and_reset } $_->items, @$item_set;
      $new_rule->{items} = \@items;
      $new_rule;
    } @price_rules, @items;
  }
}

package SL::PriceRuleMacro::Condition {
  our @ISA      = ('SL::PriceRuleMacro::Element');
}

package SL::PriceRuleMacro::Condition::ContainerAnd {
  require List::Util;
  our @ISA = ('SL::PriceRuleMacro::Condition');
  my @elements  = (qw(condition));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }

  sub type {
    'container_and'
  }

  sub cross (&$$) {
    my ($code, $x, $y) = @_;
    map {
      my $first = $_;
      map {
        $code->(local $a = $first, local $b = $_);
      } @$x
    } @$y;
  }

  sub price_rule_items {
    my $reduced = List::Util::reduce {
      [
        cross {
          [ map { $_->clone_and_reset } @$a, @$b ]
        } $a, $b
      ]
    } map {
      [ $_->price_rule_items ]
    } @{ $_[0]->condition // [] };
    @$reduced;
  }
}

package SL::PriceRuleMacro::Condition::ContainerOr {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  my @elements  = (qw(condition));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }

  sub type {
    'container_or'
  }

  sub price_rule_items {
    map { $_->price_rule_items } @{ $_[0]->condition // [] }
  }
}

package SL::PriceRuleMacro::Condition::Customer {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  my @elements  = (qw(id));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }

  sub type {
    'customer'
  }

  sub price_rule_items {
    [ SL::DB::PriceRuleItem->new(value_int => $_[0]->id, type => $_[0]->type) ];
  }
}

package SL::PriceRuleMacro::Condition::Vendor {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  my @elements  = (qw(id));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }

  sub type {
    'vendor'
  }

  sub price_rule_items {
    [ SL::DB::PriceRuleItem->new(value_int => $_[0]->id, type => $_[0]->type) ];
  }
}

package SL::PriceRuleMacro::Condition::Business {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  my @elements  = (qw(id));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }

  sub type {
    'business'
  }

  sub price_rule_items {
    [ SL::DB::PriceRuleItem->new(value_int => $_[0]->id, type => $_[0]->type) ];
  }
}

package SL::PriceRuleMacro::Condition::Part {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  my @elements  = (qw(id));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }

  sub type {
    'part'
  }

  sub price_rule_items {
    [ SL::DB::PriceRuleItem->new(value_int => $_[0]->id, type => $_[0]->type) ];
  }
}

package SL::PriceRuleMacro::Condition::Partsgroup {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  my @elements  = (qw(id));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }

  sub type {
    'partsgroup'
  }

  sub price_rule_items {
    [ SL::DB::PriceRuleItem->new(value_int => $_[0]->id, type => $_[0]->type) ];
  }
}

package SL::PriceRuleMacro::Condition::Qty {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  my @elements  = (qw(qty op));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }
  sub type {
    'qty'
  }

  sub price_rule_items {
    [ SL::DB::PriceRuleItem->new(value_num => $_[0]->qty, op => $_[0]->op, type => $_[0]->type) ];
  }
}

package SL::PriceRuleMacro::Condition::QtyRange {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  my @elements  = (qw(min max));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }

  sub type {
    'qty_range'
  }

  sub price_rule_items {
    [
      SL::DB::PriceRuleItem->new(value_num => $_[0]->min, op => 'ge', type => 'qty'),
      SL::DB::PriceRuleItem->new(value_num => $_[0]->max, op => 'le', type => 'qty'),
    ];
  }
}

package SL::PriceRuleMacro::Condition::Reqdate {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  my @elements  = (qw(reqdate op));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }

  sub type {
    'reqdate'
  }

  sub price_rule_items {
    [ SL::DB::PriceRuleItem->new(value_date => $_[0]->reqdate, op => $_[0]->op, type => $_[0]->type) ];
  }
}

package SL::PriceRuleMacro::Condition::Transdate {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  my @elements  = (qw(transdate));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }

  sub type {
    'transdate'
  }

  sub price_rule_items {
    [ SL::DB::PriceRuleItem->new(value_date => $_[0]->transdate, op => $_[0]->op, type => $_[0]->type) ];
  }
}

package SL::PriceRuleMacro::Action {
  our @ISA = ('SL::PriceRuleMacro::Element');

  sub price_rules {
    die 'needs to be implemented';
  }
}

package SL::PriceRuleMacro::ConditionalAction {
  our @ISA = ('SL::PriceRuleMacro::Element');
  my @elements  = (qw(condition action));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }

  sub type {
    'conditional_action'
  }

  sub price_rules {
    my ($self) = @_;
    my @price_rules = map { $_->price_rules }      SL::MoreCommon::listify($_[0]->action);
    my @items       = map { $_->price_rule_items } SL::MoreCommon::listify($_[0]->condition);

    my @rules = map {
      my $rule = $_;
      my $old_items = $rule->items;
      map {
        my $new_rule = $rule->clone_and_reset;
        my @items = map { $_->clone_and_reset } @$old_items, @$_;
        $new_rule->{items} = \@items;
        $new_rule;
      } @items;
    } @price_rules;

    @rules;
  }
}

package SL::PriceRuleMacro::Action::Simple {
  our @ISA = ('SL::PriceRuleMacro::Action');
  my @elements  = (qw(price discount reduction));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }

  sub type {
    'simple_action'
  }

  sub price_rules {
    SL::DB::PriceRule->new(price => $_[0]->price, discount => $_[0]->discount, reduction => $_[0]->reduction);
  }
}

package SL::PriceRuleMacro::Action::PriceScale {
  our @ISA = ('SL::PriceRuleMacro::Action');
  my @elements  = (qw(conditional_action));

  Rose::Object::MakeMethods::Generic->make_methods(scalar => [@elements]);

  sub elements {
    @elements
  }

  sub type {
    'price_scale_action'
  }

  sub price_rules {
    map { $_->price_rules } SL::MoreCommon::listify($_[0]->conditional_action);
  }
}

1;

__END__

TODO:

- meta class creation?
- validate op for qty, reqdate,
- introspection implementieren
- doku
