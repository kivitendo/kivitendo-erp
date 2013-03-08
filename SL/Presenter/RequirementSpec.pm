package SL::Presenter::RequirementSpec;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(requirement_spec_text_block_jstree_data
                 requirement_spec_item_jstree_data);

use Carp;

use SL::JSON;

sub requirement_spec_text_block_jstree_data {
  my ($self, $text_block, %params) = @_;

  return {
    data     => $text_block->title || '',
    metadata => { id =>         $text_block->id, type => 'textblock' },
    attr     => { id => "tb-" . $text_block->id, href => $params{href} || '#' },
  };
}

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

1;
