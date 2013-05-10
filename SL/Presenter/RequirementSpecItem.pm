package SL::Presenter::RequirementSpecItem;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(requirement_spec_item_tree_node_title requirement_spec_item_jstree_data requirement_spec_item_dependency_list);

use Carp;

sub requirement_spec_item_tree_node_title {
  my ($self, $item) = @_;

  return join(' ', map { $_ || '' } ($item->fb_number, $self->truncate($item->parent_id ? $item->description : $item->title, at => 30)));
}

sub requirement_spec_item_jstree_data {
  my ($self, $item, %params) = @_;

  my @children = map { $self->requirement_spec_item_jstree_data($_, %params) } @{ $item->children_sorted };
  my $type     = !$item->parent_id ? 'section' : 'function-block';
  my $class    = $type . '-context-menu';
  $class      .= ' flagged' if $item->is_flagged;

  return {
    data     => $self->requirement_spec_item_tree_node_title($item),
    metadata => { id =>         $item->id, type => $type },
    attr     => { id => "fb-" . $item->id, href => $params{href} || '#', class => $class },
    children => \@children,
  };
}

sub requirement_spec_item_dependency_list {
  my ($self, $item) = @_;

  $::locale->language_join([ map { $_->fb_number } @{ $item->dependencies } ]);
}

1;
