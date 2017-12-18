package SL::Helper::Csv::Dispatcher;

use strict;

use Data::Dumper;
use Carp;
use Scalar::Util qw(weaken);
use List::MoreUtils qw(all pairwise);
use Rose::Object::MakeMethods::Generic scalar => [ qw(
  _specs _row_class _row_spec _errors
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
  my ($self, $line) = @_;

  my $class = $self->_class_by_line($line);
  croak 'no class given' unless $class;

  eval "require " . $class;
  my $obj = $class->new;

  my $specs = $self->_specs_by_line($line);
  for my $spec (@{ $specs }) {
    $self->apply($obj, $spec, $line->{$spec->{key}});
  }

  return $obj;
}

sub _class_by_line {
  my ($self, $line) = @_;

  # initialize lookup hash if not already done
  if ($self->_csv->is_multiplexed && ! defined $self->_row_class ) {
    $self->_row_class({ map { $_->{row_ident} => $_->{class} } @{ $self->_csv->profile } });
  }

  if ($self->_csv->is_multiplexed) {
    return $self->_row_class->{$line->{datatype}};
  } else {
    return $self->_csv->profile->[0]->{class};
  }
}

sub _specs_by_line {
  my ($self, $line) = @_;

  # initialize lookup hash if not already done
  if ($self->_csv->is_multiplexed && ! defined $self->_row_spec ) {
    $self->_row_spec({ pairwise { no warnings 'once'; $a->{row_ident} => $b } @{ $self->_csv->profile }, @{ $self->_specs } });
  }

  if ($self->_csv->is_multiplexed) {
    return $self->_row_spec->{$line->{datatype}};
  } else {
    return $self->_specs->[0];
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
  my ($self, $col, $row) = @_;
  return grep { $col eq $_->{key} } @{ $self->_specs->[$row // 0] };
}

sub parse_profile {
  my ($self, %params) = @_;

  my @specs;

  my $csv_profile = $self->_csv->profile;
  my $h_aref = ($self->_csv->is_multiplexed)? $self->_csv->header : [ $self->_csv->header ];
  my $i = 0;
  foreach my $header (@{ $h_aref }) {
    my $spec = $self->_parse_profile(profile => $csv_profile->[$i]->{profile},
                                     mapping => $csv_profile->[$i]->{mapping},
                                     class   => $csv_profile->[$i]->{class},
                                     header  => $header);
    push @specs, $spec;
    $i++;
  }

  $self->_specs(\@specs);

  $self->_csv->_push_error($self->errors);

  return ! $self->errors;
}

sub _parse_profile {
  my ($self, %params) = @_;

  my $profile = $params{profile} // {};
  my $class   = $params{class};
  my $header  = $params{header};
  my $mapping = $params{mapping};

  my @specs;

  for my $col (@$header) {
    next unless $col;
    if (exists $mapping->{$col} && $profile->{$mapping->{$col}}) {
      push @specs, $self->make_spec($col, $profile->{$mapping->{$col}}, $class);
    } elsif (exists $mapping->{$col} && !%{ $profile }) {
      push @specs, $self->make_spec($col, $mapping->{$col}, $class);
    } elsif (exists $profile->{$col}) {
      push @specs, $self->make_spec($col, $profile->{$col}, $class);
    } else {
      if ($self->_csv->strict_profile) {
        $self->unknown_column($col, undef);
      } else {
        push @specs, $self->make_spec($col, $col, $class);
      }
    }
  }

  return \@specs;
}

sub make_spec {
  my ($self, $col, $path, $cur_class) = @_;

  my $spec = { key => $col, path => $path, steps => [] };

  return unless $path;

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
