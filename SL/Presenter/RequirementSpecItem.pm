package SL::Presenter::RequirementSpecItem;

use strict;

use SL::Presenter::Text qw(truncate);

use Exporter qw(import);
our @EXPORT_OK = qw(requirement_spec_item_tree_node_title requirement_spec_item_jstree_data requirement_spec_item_dependency_list);

use Carp;

sub requirement_spec_item_tree_node_title {
  my ($item) = @_;

  return join(' ', map { $_ || '' } ($item->fb_number, truncate($item->parent_id ? $item->description_as_stripped_html : $item->title, at => 30)));
}

sub tree_node_title { goto &requirement_spec_item_tree_node_title }

sub requirement_spec_item_jstree_data {
  my ($item, %params) = @_;

  my @children = map { requirement_spec_item_jstree_data($_, %params) } @{ $item->children_sorted };
  my $type     = !$item->parent_id ? 'section' : 'function-block';
  my $class    = $type . '-context-menu tooltip';
  $class      .= ' flagged' if $item->is_flagged;

  return {
    data     => requirement_spec_item_tree_node_title($item),
    metadata => { id =>         $item->id, type => $type },
    attr     => { id => "fb-" . $item->id, href => $params{href} || '#', class => $class, title => $item->content_excerpt },
    children => \@children,
  };
}

sub jstree_data { goto &requirement_spec_item_jstree_data }

sub requirement_spec_item_dependency_list {
  my ($item) = @_;

  $::locale->language_join([ map { $_->fb_number } @{ $item->dependencies } ]);
}

sub dependency_list { goto &requirement_spec_item_dependency_list }

1;
