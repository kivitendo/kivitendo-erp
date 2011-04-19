package SL::Template::Plugin::T8;

use strict;
use parent qw( Template::Plugin::Filter );

my $cached_instance;

sub new {
  my $class = shift;

  return $cached_instance ||= $class->SUPER::new(@_);
}

sub init {
  my $self = shift;

  $self->install_filter($self->{ _ARGS }->[0] || 'T8');

  return $self;
}

sub filter {
  my ($self, $text, $args) = @_;
  return $::locale->text($text, @{ $args || [] }) || $text;
}

return 'SL::Template::Plugin::T8';
