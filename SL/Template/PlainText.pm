package SL::Template::PlainText;

use SL::Template::LaTeX;

use vars qw(@ISA);

@ISA = qw(SL::Template::LaTeX);

use strict;

sub new {
  my $type = shift;

  return $type->SUPER::new(@_);
}

sub format_string {
  my ($self, $variable) = @_;

  return $variable;
}

sub get_mime_type {
  return "text/plain";
}

sub parse {
}

1;
