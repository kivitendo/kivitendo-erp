package SL::DB::Helper::Attr;

use strict;

sub auto_make {
  my ($package, %params) = @_;

  for my $col ($package->meta->columns) {
    next if $col->primary_key_position; # don't make attr helper for primary keys
    _make_by_type($package, $col->name, $col->type);
  }

  return $package;
}

sub make {
  my ($package, %params) = @_;

  for my $name (keys %params) {
    my @types = ref $params{$name} eq 'ARRAY' ? @{ $params{$name} } : ($params{$name});
    for my $type (@types) {
      _make_by_type($package, $name, $type);
    }
  }
  return $package;
}



sub _make_by_type {
  my ($package, $name, $type) = @_;
  _as_number     ($package, $name, places => -2) if $type =~ /numeric | real | float/xi;
  _as_null_number($package, $name, places => -2) if $type =~ /numeric | real | float/xi;
  _as_percent    ($package, $name, places =>  2) if $type =~ /numeric | real | float/xi;
  _as_number     ($package, $name, places =>  0) if $type =~ /int/xi;
  _as_null_number($package, $name, places =>  0) if $type =~ /int/xi;
  _as_date       ($package, $name)               if $type =~ /date | timestamp/xi;
  _as_timestamp  ($package, $name)             if $type =~ /timestamp/xi;
  _as_bool_yn    ($package, $name)               if $type =~ /bool/xi;
}

sub _as_number {
  my $package     = shift;
  my $attribute   = shift;
  my %params      = @_;

  $params{places} = 2 if !defined($params{places});

  no strict 'refs';
  *{ $package . '::' . $attribute . '_as_number' } = sub {
    my ($self, $string) = @_;

    $self->$attribute($::form->parse_amount(\%::myconfig, $string)) if @_ > 1;

    return $::form->format_amount(\%::myconfig, $self->$attribute, $params{places});
  };
}

sub _as_null_number {
  my $package     = shift;
  my $attribute   = shift;
  my %params      = @_;

  $params{places} = 2 if !defined($params{places});

  no strict 'refs';
  *{ $package . '::' . $attribute . '_as_null_number' } = sub {
    my ($self, $string) = @_;

    $self->$attribute($string eq '' ? undef : $::form->parse_amount(\%::myconfig, $string)) if @_ > 1;

    return defined $self->$attribute ? $::form->format_amount(\%::myconfig, $self->$attribute, $params{places}) : '';
  };
}

sub _as_percent {
  my $package     = shift;
  my $attribute   = shift;
  my %params      = @_;

  $params{places} = 2 if !defined($params{places});

  no strict 'refs';
  *{ $package . '::' . $attribute . '_as_percent' } = sub {
    my ($self, $string) = @_;

    $self->$attribute($::form->parse_amount(\%::myconfig, $string) / 100) if @_ > 1;

    return $::form->format_amount(\%::myconfig, 100 * $self->$attribute, $params{places});
  };

  return 1;
}

sub _as_date {
  my $package     = shift;
  my $attribute   = shift;
  my %params      = @_;

  no strict 'refs';
  *{ $package . '::' . $attribute . '_as_date' } = sub {
    my ($self, $string) = @_;

    if (@_ > 1) {
      if ($string) {
        my ($yy, $mm, $dd) = $::locale->parse_date(\%::myconfig, $string);
        $self->$attribute(DateTime->new(year => $yy, month => $mm, day => $dd));
      } else {
        $self->$attribute(undef);
      }
    }

    return $self->$attribute
      ? $::locale->reformat_date(
          { dateformat => 'yy-mm-dd' },
          ( ($self->$attribute eq 'now' || $self->$attribute eq 'now()')
             ? DateTime->now
             : $self->$attribute
          )->ymd,
          $::myconfig{dateformat}
        )
      : undef;
  };

  return 1;
}

sub _as_timestamp {
  my $package     = shift;
  my $attribute   = shift;
  my %params      = @_;

  my $accessor    = sub {
    my ($precision, $self, $string) = @_;

    $self->$attribute($string ? $::locale->parse_date_to_object($string) : undef) if @_ > 2;

    my $dt = $self->$attribute;
    return undef unless $dt;

    $dt = DateTime->now if !ref($dt) && ($dt eq 'now');

    return $::locale->format_date_object($dt, precision => $precision);
  };

  no strict 'refs';
  *{ $package . '::' . $attribute . '_as_timestamp'    } = sub { $accessor->('minute',      @_) };
  *{ $package . '::' . $attribute . '_as_timestamp_s'  } = sub { $accessor->('second',      @_) };
  *{ $package . '::' . $attribute . '_as_timestamp_ms' } = sub { $accessor->('millisecond', @_) };

  return 1;
}

sub _as_bool_yn {
  my ($package, $attribute, %params) = @_;

  no strict 'refs';
  *{ $package . '::' . $attribute . '_as_bool_yn' } = sub {
    my ($self) = @_;

    if (@_ > 1) {
      die 'not an accessor';
    }

    return !defined $self->$attribute ? ''
         :          $self->$attribute ? $::locale->text('Yes')
         :                              $::locale->text('No');
  }
}

1;


1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::Helper::Attr - attribute helpers

=head1 SYNOPSIS

  use SL::DB::Helper::Attr;
  SL::DB::Helper::Attr::make($class,
    method_name => 'numeric(15,5)',
    datemethod  => 'date'
  );
  SL::DB::Helper::Attr::auto_make($class);

=head1 DESCRIPTION

Makes attribute helpers.

=head1 FUNCTIONS

see for yourself.

=head1 BUGS

None yet.

=head1 AUTHOR

Sven Schöling <s.schoeling@linet-services.de>,
Moritz Bunkus <m.bunkus@linet-services.de>

=cut
