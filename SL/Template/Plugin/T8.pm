package SL::Template::Plugin::T8;

use strict;

use Template::Plugin::Filter;
use base qw( Template::Plugin::Filter );

sub init {
  my $self = shift;

  # first arg can specify filter name
  $self->install_filter($self->{ _ARGS }->[0] || 'T8');

  return $self;
}

sub filter {
  my ($self, $text, $args) = @_;
  return $::locale->text($text, @{ $args || [] }) || $text;
}

return 'SL::Template::Plugin::T8';
