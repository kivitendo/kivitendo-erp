package SL::Template::ShellCommand;

use parent qw(SL::Template::LaTeX);

use strict;

use String::ShellQuote;

sub new {
  my $type = shift;

  return $type->SUPER::new(@_);
}

sub substitute_vars {
  my ($self, $text, @indices) = @_;

  my $form = $self->{"form"};

  while ($text =~ /$self->{substitute_vars_re}/) {
    my ($tag_pos, $tag_len) = ($-[0], $+[0] - $-[0]);
    my ($var, @option_list) = split(/\s+/, $1);
    my %options             = map { ($_ => 1) } @option_list;

    my $value               = $self->_get_loop_variable($var, 0, @indices);
    $value                  = $form->parse_amount({ numberformat => $::myconfig{output_numberformat} || $::myconfig{numberformat} }, $value) if $options{NOFORMAT};
    $value                  = $self->format_string($value); # Don't allow NOESCAPE for arguments passed to shell commands.

    substr($text, $tag_pos, $tag_len, $value);
  }

  return $text;
}

sub format_string {
  my ($self, $variable) = @_;

  return shell_quote($variable);
}

sub get_mime_type {
  return "text/plain";
}

sub parse {
  my ($self, $text) = @_;

  return $self->parse_block($text);
}

1;
