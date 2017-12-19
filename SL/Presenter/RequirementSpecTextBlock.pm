package SL::Presenter::RequirementSpecTextBlock;

use strict;

use Exporter qw(import);
our @EXPORT_OK = qw(requirement_spec_text_block_jstree_data);

use Carp;

use SL::JSON;

sub requirement_spec_text_block_jstree_data {
  my ($text_block, %params) = @_;

  my $class  = 'text-block-context-menu tooltip';
  $class    .= ' flagged' if $text_block->is_flagged;

  return {
    data     => $text_block->title || '',
    metadata => { id =>         $text_block->id, type => 'text-block' },
    attr     => { id => "tb-" . $text_block->id, href => $params{href} || '#', class => $class, title => $text_block->content_excerpt },
  };
}

sub jstree_data { goto &requirement_spec_text_block_jstree_data }

1;
