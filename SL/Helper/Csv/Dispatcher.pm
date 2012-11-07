package SL::Helper::Csv::Dispatcher;

use strict;

use Data::Dumper;
use Carp;
use Scalar::Util qw(weaken);
use Rose::Object::MakeMethods::Generic scalar => [ qw(
  _specs _errors
) ];

use SL::Helper::Csv::Error;

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
    my ($acc, $class, $index) = @$step;
    if ($class) {

      # autovifify
      if (defined $index) {
        if (! $obj->$acc || !$obj->$acc->[$index]) {
          my @objects = $obj->$acc;
          $obj->$acc(@objects, map { $class->new } 0 .. $index - @objects);
        }
        $obj = $obj->$acc->[$index];
      } else {
        if (! $obj->$acc) {
          $obj->$acc($class->new);
        }
        $obj = $obj->$acc;
      }

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
    if ($self->_csv->strict_profile) {
      if (exists $profile->{$col}) {
        push @specs, $self->make_spec($col, $profile->{$col});
      } else {
        $self->unknown_column($col, undef);
      }
    } else {
      if (exists $profile->{$col}) {
        push @specs, $self->make_spec($col, $profile->{$col});
      } else {
        push @specs, $self->make_spec($col, $col);
      }
    }
  }

  $self->_specs(\@specs);
  $self->_csv->_push_error($self->errors);
  return ! $self->errors;
}

sub make_spec {
  my ($self, $col, $path) = @_;

  my $spec = { key => $col, steps => [] };

  return unless $path;

  my $cur_class = $self->_csv->class;

  return unless $cur_class;

  for my $step_index ( split /\.(?!\d)/, $path ) {
    my ($step, $index) = split /\./, $step_index;
    if ($cur_class->can($step)) {
      if (my $rel = $cur_class->meta->relationship($step)) { #a
        if ($index && ! $rel->isa('Rose::DB::Object::Metadata::Relationship::OneToMany')) {
          $self->_push_error([
            $path,
            undef,
            "Profile path error. Indexed relationship is not OneToMany around here: '$step_index'",
            undef,
            0,
          ]);
          return;
        } else {
          my $next_class = $cur_class->meta->relationship($step)->class;
          push @{ $spec->{steps} }, [ $step, $next_class, $index ];
          $cur_class = $next_class;
          eval "require $cur_class; 1" or die "could not load class '$cur_class'";
        }
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
  my @new_errors = ($self->errors, map { SL::Helper::Csv::Error->new(@$_) } @errors);
  $self->_errors(\@new_errors);
}

1;
