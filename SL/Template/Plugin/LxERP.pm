package SL::Template::Plugin::LxERP;

use base qw( Template::Plugin );
use Template::Plugin;

sub new {
  my $class   = shift;
  my $context = shift;

  bless { }, $class;
}

sub format_amount {
  my ($self, $var, $places, $skip_zero) = @_;

  return $main::form->format_amount(\%main::myconfig, $var * 1, $places) unless $skip_zero && $var == 0;
  return '';
}

sub format_percent {
  my ($self, $var, $places, $skip_zero) = @_;

  return $self->format_amount($var * 100, $places, $skip_zero);
}

sub escape_br {
  my ($self, $var) = @_;

  $var =~ s/\r//g;
  $var =~ s/\n/<br>/g;

  return $var;
}

1;

