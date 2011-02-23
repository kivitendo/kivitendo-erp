package SL::Helper::Csv::Dispatcher;

use strict;

use Data::Dumper;
use Carp;
use Scalar::Util qw(weaken);
use Rose::Object::MakeMethods::Generic scalar => [ qw(
  _specs _errors
) ];

sub new {
  my ($class, $parent) = @_;
  my $self = bless { }, $class;

  weaken($self->{_csv} = $parent);
  $self->_errors([]);

  return $self;
}

sub dispatch {
  my ($self, $obj, $line) = @_;

  for my $spec (@{ $self->_specs }) {
    $self->apply($obj, $spec, $line->{$spec->{key}});
  }
}

sub apply {
  my ($self, $obj, $spec, $value) = @_;
  return unless $value;

  for my $step (@{ $spec->{steps} }) {
    my ($acc, $class) = @$step;
    if ($class) {
      eval "require $class; 1" or die "could not load class '$class'";
      $obj->$acc($class->new) if ! $$obj->$acc;
      $obj = $obj->$acc;
    } else {
      $obj->$acc($value);
    }
  }
}

sub is_known {
  my ($self, $col) = @_;
  return grep { $col eq $_->{key} } $self->_specs;
}

sub parse_profile {
  my ($self, %params) = @_;

  my $header  = $self->_csv->header;
  my $profile = $self->_csv->profile;
  my @specs;

  for my $col (@$header) {
    next unless $col;
    push @specs, $self->make_spec($col, $profile->{$col} || $col);
  }

  $self->_specs(\@specs);
  $self->_csv->_push_error($self->errors);
  return ! $self->errors;
}

sub make_spec {
  my ($self, $col, $path) = @_;

  my $spec = { key => $col, steps => [] };
  my $cur_class = $self->_csv->class;

  for my $step ( split /\./, $path ) {
    if ($cur_class->can($step)) {
      if ($cur_class->meta->relationship($step)) { #a
        my $next_class = $cur_class->meta->relationsship($step)->class;
        push @{ $spec->{steps} }, [ $step, $next_class ];
        $cur_class = $next_class;
      } else { # simple dispatch
        push @{ $spec->{steps} }, [ $step ];
        last;
      }
    } else {
      $self->unknown_column($col, $path);
    }
  }

  return $spec;
}

sub unknown_column {
  my ($self, $col, $path) = @_;
  return if $self->_csv->ignore_unknown_columns;

  $self->_push_error([
    $col,
    undef,
    "header field '$col' is not recognized",
    undef,
    0,
  ]);
}

sub _csv {
  $_[0]->{_csv};
}

sub errors {
  @{ $_[0]->_errors }
}

sub _push_error {
  my ($self, @errors) = @_;
  my @new_errors = ($self->errors, @errors);
  $self->_errors(\@new_errors);
}

1;
