#====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#====================================================================

package SL::Template::Simple;

use strict;

use Scalar::Util qw(blessed);

# Parameters:
#   1. The template's file name
#   2. A reference to the Form object
#   3. A reference to the myconfig hash
#
# Returns:
#   A new template object
sub new {
  my $type = shift;
  my $self = {};

  bless($self, $type);
  $self->_init(@_);

  return $self;
}

sub _init {
  my ($self, %params) = @_;

  $params{myconfig}  ||= \%::myconfig;
  $params{userspath} ||= $::lx_office_conf{paths}->{userspath};

  $self->{$_} = $params{$_} for keys %params;

  $self->{variable_content_types}        ||= {};
  $self->{variable_content_types}->{$_}    = lc $self->{variable_content_types}->{$_} for keys %{ $self->{variable_content_types} };
  $self->{default_variable_content_type}   = 'text';

  $self->{error}     = undef;
  $self->{quot_re}   = '"';

  $self->set_tag_style('<%', '%>');
}

sub set_tag_style {
  my $self                    = shift;
  my $tag_start               = shift;
  my $tag_end                 = shift;

  $self->{custom_tag_style}   = 1;
  $self->{tag_start}          = $tag_start;
  $self->{tag_end}            = $tag_end;
  $self->{tag_start_qm}       = quotemeta $tag_start;
  $self->{tag_end_qm}         = quotemeta $tag_end;

  $self->{substitute_vars_re} = "$self->{tag_start_qm}(.+?)$self->{tag_end_qm}";
}

sub set_use_template_toolkit {
  my $self                    = shift;
  my $value                   = shift;

  $self->{use_template_toolkit} = $value;
}

sub cleanup {
  my ($self) = @_;
}

# Parameters:
#   1. A typeglob for the file handle. The output will be written
#      to this file handle.
#
# Returns:
#   1 on success and undef or 0 if there was an error. In the latter case
#   the calling function can retrieve the error message via $obj->get_error()
sub parse {
  my $self = $_[0];
  local *OUT = $_[1];

  print(OUT "Hallo!\n");
}

sub get_error {
  my $self = shift;

  return $self->{"error"};
}

sub uses_temp_file {
  return 0;
}

sub _get_loop_variable {
  my ($self, $var, $get_array, @indices) = @_;
  my $form      = $self->{form};
  my ($value, @methods);

  if ($var =~ m/\./) {
    ($var, @methods) = split m/\./, $var;
  }

  if (($get_array || @indices) && (ref $form->{TEMPLATE_ARRAYS} eq 'HASH') && (ref $form->{TEMPLATE_ARRAYS}->{$var} eq 'ARRAY')) {
    $value = $form->{TEMPLATE_ARRAYS}->{$var};
  } else {
    $value = $form->{$var};
  }

  for (my $i = 0; $i < scalar(@indices); $i++) {
    last unless (ref($value) eq "ARRAY");
    $value = $value->[$indices[$i]];
  }

  for my $part (@methods) {
    if (ref($value) =~ m/^(?:Form|HASH)$/) {
      $value = $value->{$part};
    } elsif (blessed($value) && $value->can($part)) {
      $value = $value->$part;
    } else {
      $value = '';
      last;
    }
  }

  return $value;
}

sub substitute_vars {
  my ($self, $text, @indices) = @_;

  my $form = $self->{"form"};

  while ($text =~ /$self->{substitute_vars_re}/) {
    my ($tag_pos, $tag_len) = ($-[0], $+[0] - $-[0]);
    my ($var, @option_list) = split(/\s+/, $1);
    my %options             = map { ($_ => 1) } @option_list;

    my $value               = $self->_get_loop_variable($var, 0, @indices);
    $value                  = $form->parse_amount({ numberformat => $::myconfig{output_numberformat} || $::myconfig{numberformat} }, $value) if     $options{NOFORMAT};
    $value                  = $self->format_string($value, $var)                                                                             unless $options{NOESCAPE};

    substr($text, $tag_pos, $tag_len, $value);
  }

  return $text;
}

sub _parse_block_if {
  $main::lxdebug->enter_sub();

  my $self         = shift;
  my $contents     = shift;
  my $new_contents = shift;
  my $pos_if       = shift;
  my @indices      = @_;

  $$new_contents .= $self->substitute_vars(substr($$contents, 0, $pos_if), @indices);
  substr($$contents, 0, $pos_if) = "";

  if ($$contents !~ m/^( $self->{tag_start_qm}if
                     \s*
                     (not\b|\!)?           # $2 -- Eventuelle Negierung
                     \s+
                     (\b.+?\b)             # $3 -- Name der zu überprüfenden Variablen
                     (                     # $4 -- Beginn des optionalen Vergleiches
                       \s*
                       ([!=])              # $5 -- Negierung des Vergleiches speichern
                       ([=~])              # $6 -- Art des Vergleiches speichern
                       \s*
                       (                   # $7 -- Gequoteter String oder Bareword
                         $self->{quot_re}
                         (.*?)(?<!\\)      # $8 -- Gequoteter String -- direkter Vergleich mit eq bzw. ne oder Patternmatching; Escapete Anführungs als Teil des Strings belassen
                         $self->{quot_re}
                       |
                         (\b.+?\b)         # $9 -- Bareword -- als Index für $form benutzen
                       )
                     )?
                     \s*
                     $self->{tag_end_qm} )
                    /x) {
    $self->{"error"} = "Malformed $self->{tag_start}if$self->{tag_end}.";
    $main::lxdebug->leave_sub();
    return undef;
  }

  my $not           = $2;
  my $var           = $3;
  my $comparison    = $4; # Optionaler Match um $4..$8
  my $operator_neg  = $5; # '=' oder '!' oder undef, wenn kein Vergleich erkannt
  my $operator_type = $6; # '=' oder '~' für Stringvergleich oder Regex
  my $quoted_word   = $8; # nur gültig, wenn quoted string angegeben (siehe unten); dann "value" aus <%if var == "value" %>
  my $bareword      = $9; # undef, falls quoted string angegeben wurde; andernfalls "othervar" aus <%if var == othervar %>

  $not = !$not if ($operator_neg && $operator_neg eq '!');

  substr($$contents, 0, length($1)) = "";

  my $block;
  ($block, $$contents) = $self->find_end($$contents, 0, "$var $comparison", $not);
  if (!$block) {
    $self->{"error"} = "Unclosed $self->{tag_start}if$self->{tag_end}." unless ($self->{"error"});
    $main::lxdebug->leave_sub();
    return undef;
  }

  my $value = $self->_get_loop_variable($var, 0, @indices);
  $value    = scalar(@{ $value }) if (ref($value) || '') eq 'ARRAY';
  my $hit   = 0;

  if ($operator_type) {
    my $compare_to = $bareword ? $self->_get_loop_variable($bareword, 0, @indices) : $quoted_word;
    if ($operator_type eq '=') {
      $hit         = ($not && !($value eq $compare_to))     || (!$not && ($value eq $compare_to));
    } else {
      $hit         = ($not && !($value =~ m/$compare_to/i)) || (!$not && ($value =~ m/$compare_to/i));
    }

  } else {
    $hit           = ($not && ! $value)                     || (!$not &&  $value);
  }

  if ($hit) {
    my $new_text = $self->parse_block($block, @indices);
    if (!defined($new_text)) {
      $main::lxdebug->leave_sub();
      return undef;
    }
    $$new_contents .= $new_text;
  }

  $main::lxdebug->leave_sub();

  return 1;
}

1;
