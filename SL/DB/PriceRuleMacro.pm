# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::PriceRuleMacro;

use strict;

use SL::DB::MetaSetup::PriceRuleMacro;
use SL::DB::Manager::PriceRuleMacro;
use SL::MoreCommon;

use SL::Presenter::CustomerVendor;
use SL::Presenter::Part;

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
  definition            => 'SL::PriceRuleMacro::Definition',
  condition             => 'SL::PriceRuleMacro::Condition',
  container_and         => 'SL::PriceRuleMacro::Condition::ContainerAnd',
  container_or          => 'SL::PriceRuleMacro::Condition::ContainerOr',
  customer              => 'SL::PriceRuleMacro::Condition::Customer',
  vendor                => 'SL::PriceRuleMacro::Condition::Vendor',
  business              => 'SL::PriceRuleMacro::Condition::Business',
  part                  => 'SL::PriceRuleMacro::Condition::Part',
  partsgroup            => 'SL::PriceRuleMacro::Condition::Partsgroup',
  pricegroup            => 'SL::PriceRuleMacro::Condition::Pricegroup',
  qty                   => 'SL::PriceRuleMacro::Condition::Qty',
  qty_range             => 'SL::PriceRuleMacro::Condition::QtyRange',
  reqdate               => 'SL::PriceRuleMacro::Condition::Reqdate',
  transdate             => 'SL::PriceRuleMacro::Condition::Transdate',
  action                => 'SL::PriceRuleMacro::Action',
  conditional_action    => 'SL::PriceRuleMacro::ConditionalAction',
  simple_action         => 'SL::PriceRuleMacro::Action::Simple',
  price_scale_action    => 'SL::PriceRuleMacro::Action::PriceScale',
);
my %r_classes = reverse %classes;

sub create_definition_meta {
  +{
    map {
      my $type = $_;
      $type => {
        has_elements => {
          map {
            $_ => {
              type => $classes{$_} ? $_ : undef,
              can_be_array => $classes{$type}->can_array($_),
            }
          } $classes{$type}->safe_elements
        },
        can_be => [
          grep { $classes{$_} ne $classes{$type} && $classes{$_}->isa($classes{$type}) } keys %classes
        ],
        abstract => $classes{$type}->abstract ? 1 : 0,
        internal_class => $classes{$type},
      }
    } keys %classes
  }
}

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

  sub abstract {
    ! eval { $_[0]->elements; 1 }
  }

  sub safe_elements {
    $_[0]->abstract ? () : $_[0]->elements
  }

  sub array_elements {}

  sub can_array {
    for ($_[0]->array_elements) {
      return 1 if $_ eq $_[1]
    }
    return 0
  }

  sub as_tree {
    my ($self, $slot) = @_;

    my $obj = {};

    for my $method ($self->elements) {
      my $val = $self->$method;
      my $ref;

      next unless defined $val;

      if ($classes{$method}) {
        if ('ARRAY' eq ref $val) {
          $ref = [ map { $_->as_tree($method) } @$val ];
        } elsif (ref $val) {
          $ref = $val->as_tree($method);
        } else {
          die "encountered non-blessed, non-ref value for class method '$method' in @{[ ref $self ]}";
        }
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
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(condition action name priority obsolete format_version)
  }

  sub array_elements {
    qw(condition action)
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
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(condition)
  }

  sub array_elements {
    qw(condition)
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
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(condition)
  }

  sub array_elements {
    qw(condition)
  }

  sub type {
    'container_or'
  }

  sub price_rule_items {
    map { $_->price_rule_items } @{ $_[0]->condition // [] }
  }
}

package SL::PriceRuleMacro::IdCondition {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(id)
  }

  sub array_elements {
    qw(id)
  }

  sub price_rule_items {
    map { [ SL::DB::PriceRuleItem->new(value_int => $_, type => $_[0]->type) ] } SL::MoreCommon::listify($_[0]->id);
  }
}

package SL::PriceRuleMacro::Condition::Customer {
  our @ISA = ('SL::PriceRuleMacro::IdCondition');

  sub type {
    'customer'
  }

  sub picker {
    my ($class, %params) = @_;
    my $name  = delete $params{name};
    my $value = delete $params{id};
    SL::Presenter::CustomerVendor::customer_vendor_picker($name, $value, type => 'customer');
  }
}

package SL::PriceRuleMacro::Condition::Vendor {
  our @ISA = ('SL::PriceRuleMacro::IdCondition');

  sub type {
    'vendor'
  }

  sub picker {
    my ($class, %params) = @_;
    my $name  = delete $params{name};
    my $value = delete $params{id};
    SL::Presenter::CustomerVendor::customer_vendor_picker($name, $value, type => 'vendor');
  }
}

package SL::PriceRuleMacro::Condition::Business {
  our @ISA = ('SL::PriceRuleMacro::IdCondition');

  sub type {
    'business'
  }
}

package SL::PriceRuleMacro::Condition::Part {
  our @ISA = ('SL::PriceRuleMacro::IdCondition');

  sub type {
    'part'
  }

  sub picker {
    my ($class, %params) = @_;
    my $name  = delete $params{name};
    my $value = delete $params{id};
    SL::Presenter::Part::part_picker($name, $value);
  }
}

package SL::PriceRuleMacro::Condition::Partsgroup {
  our @ISA = ('SL::PriceRuleMacro::IdCondition');

  sub type {
    'partsgroup'
  }
}

package SL::PriceRuleMacro::Condition::Pricegroup {
  our @ISA = ('SL::PriceRuleMacro::IdCondition');

  sub type {
    'pricegroup'
  }
}

package SL::PriceRuleMacro::Condition::Qty {
  our @ISA = ('SL::PriceRuleMacro::Condition');
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(qty op)
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
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(min max)
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
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(reqdate op)
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
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(transdate)
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
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(condition action)
  }

  sub array_elements {
    qw(condition action)
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
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(price discount reduction)
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
  Rose::Object::MakeMethods::Generic->make_methods(scalar => [__PACKAGE__->elements]);

  sub elements {
    qw(conditional_action)
  }

  sub array_elements {
    qw(conditional_action)
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

=encoding utf-8

=head1 NAME

SL::DB::PriceRuleMacro - wrapper for primitive price rules

=head1 SYNOPSIS

  use SL::;

=head1 DESCRIPTION

Primitive price rules have a very strict format for efficiency reasons. They
have exactly one action, and a number of conditions that all must match:

  If qty > 10 and parts_id = 349 then set price to 10.00

In practice these are cumbersome to use, so this additional layer provides the
possibility to construct more complex rules that are then compiled into the
primitive format.

=head1 METHODS

=over 4

=item * C<json_definition>

=item * C<definition>

The first one takes and stores raw json, the second one converts to and from
that to a Perl data structure.

=item * C<parsed_definition>

Parses the definition found in L</json_definition> into a class structure
representing it. The result is cached.

=item * C<update_definition>

Copies the meta attibutes C<name>, C<priority>, C<obsolete>, C<type> from the
macro object into the definition.

=item * C<copy_attributes_to_price_rules PRICE_RULES>

Copies the meta attributes C<name>, C<priority>, C<obsolete>, C<type> from the
macro object into the given price_rules.

=item * C<create_definition_meta>

Returns a structure detailing the accepted elements for the
C<SL::PriceRuleMacro::Definition> elements.

=back

=head1 INTERNAL HELPER CLASSES

The implementation uses a parser based on the helper class
C<SL::PriceRuleMacro::Element>. This abstract class interface provides
the following methods:

=over 4

=item * C<elements>

Returns a list of fields that this element accepts. Can be used for introspection

=item * C<array_elements>

Returns a list of the fields that may be arrays instead of scalars.

=item * C<can_array FIELD>

Returns true if the field may be an array.

=item * C<abstract>

Returns ture if this element can not be filled directly. Abstract classes must
always have have alternatives.

=item * C<as_tree>

Returns a recursive hasref representation of the object tree from this point.
Used for roundtrip.

=item * C<type>

For classes that can be polymorph, C<type> provides the identification for
roundtrip safety.

=back

The actual tree structure will be a C<SL::PriceRuleMacro::Definition>,
which contains two distinct sections: C<condition> and C<action>. Condition
will be a C<SL::PriceRuleMacro::Condition> and action will be a
C<SL::PriceRuleMacro::Action>.

These three implement two additional methods:

=over 4

=item * C<price_rules>

In definition and actions. This returns the compiled L<SL::DB::PriceRule>
objects the tree represents from this point on. Note: The items will be added
in hash slot and need to be readded before saving them.

=item * C<price_rule_items>

In conditions. This returns a list of L<SL::DB::PriceRuleItem> arrays that this
subtree represents. Each array is one conjuction of rules.

=back

=head1 BUGS

None yet :)

=head1 AUTHOR

Sven Schöling E<lt>sven.schoeling@opendynamic.deE<gt>

=cut

__END__

TODO:

- validate/parse op for qty, reqdate,
- format_version checking
