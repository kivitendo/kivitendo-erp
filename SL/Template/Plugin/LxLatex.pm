package SL::Template::Plugin::LxLatex;

use strict;
use parent qw( Template::Plugin );

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
  return $::locale->quote_special_chars('Template/LaTeX', $text);
}

return 'SL::Template::Plugin::LxLatex';
