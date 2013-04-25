package SL::Template::Plugin::LxLatex;

use strict;
use parent qw( Template::Plugin::Filter );

my $cached_instance;

sub new {
  my $class = shift;

  return $cached_instance ||= $class->SUPER::new(@_);
}

sub init {
  my $self = shift;

  $self->install_filter($self->{ _ARGS }->[0] || 'LxLatex');

  return $self;
}

sub filter {
  my ($self, $text, $args) = @_;
  return $::locale->quote_special_chars('Template/LaTeX', $text);
}

return 'SL::Template::Plugin::LxLatex';
