# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::PartsGroup;

use strict;

use SL::DB::MetaSetup::PartsGroup;
use SL::DB::Manager::PartsGroup;
use SL::DB::Helper::ActsAsList;
use SL::DB::Helper::AttrSorted;
use SL::DBUtils qw(selectall_array_query);

__PACKAGE__->configure_acts_as_list(group_by => [qw(parent_id)]);
__PACKAGE__->attr_sorted({ unsorted => 'children', position => 'sortkey' });

__PACKAGE__->meta->add_relationship(
  custom_variable_configs => {
    type                  => 'many to many',
    map_class             => 'SL::DB::CustomVariableConfigPartsgroup',
  },
  parts          => {
    type         => 'one to many',
    class        => 'SL::DB::Part',
    column_map   => { id => 'partsgroup_id' },
    add_methods  => ['count'],
  },
 children  => {
   type         => 'one to many',
   class        => 'SL::DB::PartsGroup',
   column_map   => { id => 'parent_id' },
   add_methods  => ['count'],
 }
);

__PACKAGE__->meta->initialize;

sub displayable_name {
  my $self = shift;

  return $self->partsgroup;
}

sub indented_name {
  my $self = shift;
  # used for label in select_tag

  return '  -  ' x $self->get_level . $self->partsgroup;
}

sub validate {
  my ($self) = @_;
  require SL::DB::Customer;

  my @errors;

  push @errors, $::locale->text('The description is missing.') if $self->id and !$self->partsgroup;

  return @errors;
}

sub orphaned {
  my ($self) = @_;
  die 'not an accessor' if @_ > 1;

  return 1 unless $self->id;

  my @relations = qw(
    SL::DB::Part
    SL::DB::CustomVariableConfigPartsgroup
  );

  for my $class (@relations) {
    eval "require $class";
    return 0 if $class->_get_manager_class->get_all_count(query => [ partsgroup_id => $self->id ]);
  }

  eval "require SL::DB::PriceRuleItem";
  return 0 if SL::DB::Manager::PriceRuleItem->get_all_count(query => [ type => 'partsgroup', value_int => $self->id ]);

  return 0 if SL::DB::Manager::PartsGroup->get_all_count(query => [ parent_id => $self->id ]);

  return 1;
}

sub ancestors {
  my ($self) = @_;

  my @ancestors = ();
  my $pg = $self;

  return \@ancestors unless defined $self->parent;

  while ( $pg->parent_id ) {
    $pg = $pg->parent;
    unshift(@ancestors, $pg);
  };

  return \@ancestors;
}

sub ancestor_ids {
  my ($self) = @_;

  my $query = <<SQL;
WITH RECURSIVE rec (id) as
(
  SELECT partsgroup.id, partsgroup.parent_id from partsgroup where partsgroup.id = ?
  UNION ALL
  SELECT partsgroup.id, partsgroup.parent_id from rec, partsgroup where partsgroup.id = rec.parent_id
)
SELECT id as ancestors
  FROM rec
SQL
  my @ids = selectall_array_query($::form, $self->dbh, $query, $self->id);
  return \@ids;
}

sub partsgroup_iterator_dfs {
  # partsgroup iterator that starts with a partsgroup, using depth first search
  # to iterate over partsgroups you have to first find the roots (level 0) and
  # then use this method to recursively dig down and find all the children
  my ($self) = @_;
  my @queue ;

  @queue = @{ $self->children_sorted } if $self->children_count;

  return sub {
    while ( @queue ) {
      my $pg = shift @queue;

      if ( scalar @{ $pg->children_sorted } ) {
        unshift @queue, @{ $pg->children_sorted };
      };
      return $pg;
    };
    return;
  };
}

sub get_level {
  my ($self) = @_;
  # iterate through parents to calculate the level

  return 0 unless defined $self->parent;
  return $self->{cached_level} if exists $self->{cached_level};
  my $level = 1;
  my $parent = $self->parent;
  while ( $parent->parent ) {
    $level++;
    $parent = $parent->parent;
  };
  return $self->{cached_level} = $level;
}

1;
