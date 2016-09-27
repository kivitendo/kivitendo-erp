package SL::Auth::ColumnInformation;

use strict;

use Carp;
use Scalar::Util qw(weaken);

use SL::DBUtils;

sub new {
  my ($class, %params) = @_;

  my $self = bless {}, $class;

  $self->{auth} = $params{auth} || croak "Missing 'auth'";
  weaken $self->{auth};

  return $self;
}

sub _fetch {
  my ($self) = @_;

  return $self if $self->{info};

  $self->{info} = {};

  foreach my $table (qw(session session_content)) {
    my $query = <<SQL;
      SELECT a.attname, format_type(a.atttypid, a.atttypmod) AS format_type, d.adsrc, a.attnotnull
      FROM pg_attribute a
      LEFT JOIN pg_attrdef d ON (a.attrelid = d.adrelid) AND (a.attnum = d.adnum)
      WHERE (a.attrelid = 'auth.${table}'::regclass)
        AND (a.attnum > 0)
        AND NOT a.attisdropped
      ORDER BY a.attnum
SQL

    $self->{info}->{$table} = { selectall_as_map($::form, $self->{auth}->dbconnect, $query, 'attname', [ qw(format_type adsrc attnotnull) ]) };
  }

  return $self;
}

sub info {
  my ($self) = @_;
  return $self->_fetch->{info};
}

sub has {
  my ($self, $column, $table) = @_;
  return $self->info->{$table || 'session_content'}->{$column};
}

1;
