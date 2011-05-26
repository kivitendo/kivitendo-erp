package SL::Template::Excel;

use strict;
use parent qw(SL::Template::Simple);

sub new {
  my $type = shift;

  my $self = $type->SUPER::new(@_);

  return $self;
}

sub _init {
  my $self = shift;

  $self->{source}    = shift;
  $self->{form}      = shift;
  $self->{myconfig}  = shift;
  $self->{userspath} = shift;

  $self->{error}     = undef;

  $self->set_tag_style('<<', '>>');
}

sub get_mime_type() {
  my ($self) = @_;

  return "application/msexcel";
}

sub uses_temp_file {
  return 1;
}

sub parse {
  $main::lxdebug->enter_sub();

  my $self   = shift;
  local *OUT = shift;
  my $form   = $self->{"form"};

  open(IN, "$form->{templates}/$form->{IN}") or do { $self->{"error"} = "$!"; return 0; };
  my @lines = <IN>;
  close IN;

  my $contents = join("", @lines);
  my @indices;
  $contents =~ s%
    ( $self->{tag_start} [<]* (\s?) [<>\s]* ([\w\s]+) [<>\s]* $self->{tag_end} )
  %
    $self->format_vars(align_right => $2 ne '', varstring => $3, length => length($1), indices =>  \@indices)
  %egx;

  if (!defined($contents)) {
    $main::lxdebug->leave_sub();
    return 0;
  }

  print OUT $contents;

  $main::lxdebug->leave_sub();
  return 1;
}

sub format_vars {
  my ($self, %params) = @_;
  my $form            = $self->{"form"};
  my @indices         = @{ $params{indices} };
  my $align_right     = $params{align_right};
  my $varstring       = $params{varstring};
  my $length          = $params{length};

  $varstring =~ s/(\w+)/ $self->_get_loop_variable($1, 0, @indices) /eg;
  my $old_string=$varstring;
  my $new_string = sprintf "%*s", ($align_right ? 1 : -1 ) * $length, $varstring;
  return substr $new_string, ($align_right ? (0, $length) : -$length);
}

1;
