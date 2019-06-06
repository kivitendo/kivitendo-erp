package SL::Auth::SessionValue;

use strict;

# Classes that overload stringification must be known before
# YAML::Load() is called.
use SL::Locale::String ();

use Scalar::Util qw(weaken);

use SL::DBUtils;
use SL::YAML;

sub new {
  my ($class, %params) = @_;

  my $self = bless {}, $class;

  map { $self->{$_} = $params{$_} } qw(auth key value auto_restore modified);

  $self->{fetched} =                  exists $params{value};
  $self->{parsed}  = !$params{raw} && exists $params{value};

  # delete $self->{auth};
  # $::lxdebug->dump(0, "NEW", $self);
  # $self->{auth} = $params{auth};

  weaken $self->{auth};

  return $self;
}

sub get {
  my ($self) = @_;
  return $self->_fetch->_parse->{value};
}

sub get_dumped {
  my ($self) = @_;
  no warnings 'once';
  local $YAML::Stringify = 1;
  return SL::YAML::Dump($self->get);
}

sub _fetch {
  my ($self) = @_;

  return $self if $self->{fetched};
  return $self if !$self->{auth}->session_tables_present;

  my $dbh          = $self->{auth}->dbconnect;
  my $query        = qq|SELECT sess_value FROM auth.session_content WHERE (session_id = ?) AND (sess_key = ?)|;
  ($self->{value}) = selectfirst_array_query($::form, $dbh, $query, $self->{auth}->get_session_id, $self->{key});
  $self->{fetched} = 1;

  return $self;
}

sub _parse {
  my ($self) = @_;

  $self->{value}  = SL::YAML::Load($self->{value}) unless $self->{parsed};
  $self->{parsed} = 1;

  return $self;
}

sub _load_value {
  my ($self, $value) = @_;

  return { simple => 1, data => $value } if $value !~ m/^---/;

  my %params = ( simple => 1 );
  eval {
    my $data = SL::YAML::Load($value);

    if (ref $data eq 'HASH') {
      map { $params{$_} = $data->{$_} } keys %{ $data };
      $params{simple} = 0;

    } else {
      $params{data}   = $data;
    }

    1;
  } or $params{data} = $value;

  return \%params;
}

1;
