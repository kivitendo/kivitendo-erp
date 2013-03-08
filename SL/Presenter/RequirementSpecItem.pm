package SL::Presenter::RequirementSpecItem;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(requirement_spec_item_jstree_data requirement_spec_item_dependency_list);

use Carp;

sub requirement_spec_item_jstree_data {
  my ($self, $item, %params) = @_;

  my @children = map { $self->requirement_spec_item_jstree_data($_, %params) } @{ $item->sorted_children };
  my $type     = !$item->parent_id ? 'section' : 'functionblock';

  return {
    data     => join(' ', map { $_ || '' } ($item->fb_number, $item->title)),
    metadata => { id =>         $item->id, type => $type },
    attr     => { id => "fb-" . $item->id, href => $params{href} || '#' },
    children => \@children,
  };
}

sub requirement_spec_item_dependency_list {
  my ($self, $item) = @_;

  $::locale->language_join([ map { $_->fb_number } @{ $item->dependencies } ]);
}

1;
