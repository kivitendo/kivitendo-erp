package SL::Layout::Split;

use strict;
use parent qw(SL::Layout::Base);

use SL::Presenter::Tag qw(html_tag);

use Rose::Object::MakeMethods::Generic (
  'scalar'                => [ qw(left right) ],
);

sub sub_layouts {
  @{ $_[0]->left || [] },
  @{ $_[0]->right || [] },
}

sub pre_content {
  my $left  = join '', map { $_->pre_content } @{ $_[0]->left  || [] };
  my $right = join '', map { $_->pre_content } @{ $_[0]->right || [] };

  html_tag('div', $left, class => 'layout-split-left')
  .'<div class="layout-split-right">' . $right;
}

sub post_content {
  my $left  = join '', map { $_->post_content } @{ $_[0]->left  || [] };
  my $right = join '', map { $_->post_content } @{ $_[0]->right || [] };

  $right . '</div>'
  . html_tag('div', $left, class => 't-layout-left');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Layout::Split

=head1 SYNOPSIS

  use SL::Layout::TLayout;

  SL::Layout::TLayout->new(
    left  => [ LIST OF SUBLAYOUTS ],
    right => [ LIST OF SUBLAYOUTS ],
  );

=head1 DESCRIPTION

Layout with left and right components, with content being part of the
right block.

=head1 BUGS

Due to the way content is serialized it's currently not possible to shift the content into the other blocks

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
