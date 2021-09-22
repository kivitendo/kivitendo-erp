package SL::Template::Plugin::LxERP;

use base qw( Template::Plugin );
use Scalar::Util qw();
use Template::Plugin;

use List::Util qw(min);

use SL::AM;

use strict;

sub new {
  my $class   = shift;
  my $context = shift;

  bless { }, $class;
}

sub is_rdbo {
  my ($self, $obj, $wanted_class) = @_;

  $wanted_class = !$wanted_class         ? 'Rose::DB::Object'
                : $wanted_class =~ m{::} ? $wanted_class
                :                          "SL::DB::${wanted_class}";

  return Scalar::Util::blessed($obj) ? $obj->isa($wanted_class) : 0;
}

sub format_amount {
  my ($self, $var, $places, $skip_zero, $dash) = @_;

  return $main::form->format_amount(\%main::myconfig, $var * 1, $places, $dash) unless $skip_zero && $var == 0;
  return '';
}

sub round_amount {
  my ($self, $var, $places, $skip_zero) = @_;

  return $main::form->round_amount($var * 1, $places) unless $skip_zero && $var == 0;
  return '';
}

sub format_percent {
  my ($self, $var, $places, $skip_zero) = @_;

  $places ||= 2;

  return $self->format_amount($var * 100, $places, $skip_zero);
}

sub escape_br {
  my ($self, $var) = @_;

  $var =~ s/\r//g;
  $var =~ s/\n/<br>/g;

  return $var;
}

sub format_string {
  my $self   = shift;
  my $string = shift;

  return $main::form->format_string($string, @_);
}

sub numtextrows {
  my $self = shift;

  return $main::form->numtextrows(@_);
}

sub _turn90_word {
  my $self = shift;
  my $word = shift || "";

  return join '<br>', map { $main::locale->quote_special_chars('HTML', $_) } split(m//, $word);
}

sub turn90 {
  my $self            = shift;
  my $word            = shift;
  my $args            = shift;

  $args             ||= { };
  $word             ||= "";

  $args->{split_by} ||= 'chars';
  $args->{class}      = " class=\"$args->{class}\"" if ($args->{class});

  if ($args->{split_by} eq 'words') {
    my @words = split m/\s+/, $word;

    if (1 >= scalar @words) {
      return $self->_turn90_word($words[0]);
    }

    return qq|<table><tr>| . join('', map { '<td valign="bottom"' . $args->{class} . '>' . $self->_turn90_word($_) . '</td>' } @words) . qq|</tr></table>|;

  } else {
    return $self->_turn90_word($word);
  }
}

sub abs {
  my $self = shift;
  my $var  = shift;

  return $var < 0 ? $var * -1 : $var;
}

sub t8 {
  my ($self, $text, @args) = @_;
  return $::locale->text($text, @args) || $text;
}

1;
