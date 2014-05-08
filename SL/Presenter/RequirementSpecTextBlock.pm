package SL::Presenter::RequirementSpecTextBlock;

use strict;

use parent qw(Exporter);

use Exporter qw(import);
our @EXPORT = qw(requirement_spec_text_block_jstree_data);

use Carp;

use SL::JSON;

sub requirement_spec_text_block_jstree_data {
  my ($self, $text_block, %params) = @_;

  my $class  = 'text-block-context-menu tooltip';
  $class    .= ' flagged' if $text_block->is_flagged;

  return {
    data     => $text_block->title || '',
    metadata => { id =>         $text_block->id, type => 'text-block' },
    attr     => { id => "tb-" . $text_block->id, href => $params{href} || '#', class => $class, title => $text_block->content_excerpt },
  };
}

1;
