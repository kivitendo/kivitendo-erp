# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::CustomVariableConfig;

use strict;

use SL::DB::MetaSetup::CustomVariableConfig;
use SL::DB::Manager::CustomVariableConfig;
use SL::DB::Helper::ActsAsList;

__PACKAGE__->meta->initialize;

__PACKAGE__->configure_acts_as_list(group_by => [qw(module)]);

sub validate {
  my ($self) = @_;

  my @errors;
  push @errors, $::locale->text('The name is missing.')        if !$self->name;
  push @errors, $::locale->text('The description is missing.') if !$self->description;
  push @errors, $::locale->text('The type is missing.')        if !$self->type;
  push @errors, $::locale->text('The option field is empty.')  if (($self->type || '') eq 'select') && !$self->options;

  return @errors;
}

use constant OPTION_DEFAULTS =>
  {
    MAXLENGTH => 75,
    WIDTH => 30,
    HEIGHT => 5,
  };

sub processed_options {
  my ($self) = @_;

  if( exists($self->{processed_options_cache}) ) {
    return $self->{processed_options_cache};
  }

  my $ops = $self->options;
  my $ret;

  if ( $self->type eq 'select' ) {
    my @op_array = split('##', $ops);
    $ret = \@op_array;
  }
  else {
    $ret = {%{$self->OPTION_DEFAULTS}};
    while ( $ops =~ /\s*([^=\s]+)\s*=\s*([^\s]*)(?:\s*|$)/g ) {
      $ret->{$1} = $2;
    }
  }

  $self->{processed_options_cache} = $ret;

  return $ret;
}

sub processed_flags {
  my ($self) = @_;

  if( exists($self->{processed_flags_cache}) ) {
    return $self->{processed_flags_cache};
  }

  my $flags = $self->flags;
  my $ret;

  foreach my $flag (split m/:/, $flags) {
    if ( $flag =~ m/(.*?)=(.*)/ ) {
      $ret->{$1} = $2;
    } else {
      $ret->{$flag} = 1;
    }
  }

  $self->{processed_flags_cache} = $ret;

  return $ret;
}

sub has_flag {
  my ($self, $flag) = @_;

  return $self->processed_flags()->{$flag};
}

1;
