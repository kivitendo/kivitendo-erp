package SL::Presenter::RequirementSpecTextBlock;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(requirement_spec_text_block_jstree_data);

use Carp;

use SL::JSON;

sub requirement_spec_text_block_jstree_data {
  my ($self, $text_block, %params) = @_;

  return {
    data     => $text_block->title || '',
    metadata => { id =>         $text_block->id, type => 'textblock' },
    attr     => { id => "tb-" . $text_block->id, href => $params{href} || '#', class => 'text-block-context-menu' },
  };
}

1;
