package SL::LxOfficeConf;

use strict;

use Encode;

my $environment_initialized;

sub safe_require {
  my ($class, $may_fail) = @_;

  eval {
    require Config::Std;
    require SL::System::Process;
    1;
  } or do {
    if ($may_fail) {
      warn $@;
      return 0;
    } else {
      die $@;
    }
  };

  Config::Std->import;

  return 1;
}

sub read {
  my ($class, $file_name, $may_fail) = @_;

  return unless $class->safe_require($may_fail);

  # Backwards compatibility: read lx_office.conf.default if
  # kivitendo.conf.default does't exist.
  my $dir            = SL::System::Process->exe_dir;
  my $default_config = -f "${dir}/config/kivitendo.conf.default" ? 'kivitendo' : 'lx_office';
  read_config("${dir}/config/${default_config}.conf.default" => \%::lx_office_conf);
  _decode_recursively(\%::lx_office_conf);

  $file_name ||= -f "${dir}/config/kivitendo.conf" ? "${dir}/config/kivitendo.conf" : "${dir}/config/lx_office.conf";

  if (-f $file_name) {
    read_config($file_name => \ my %local_conf);
    _decode_recursively(\%local_conf);
    _flat_merge(\%::lx_office_conf, \%local_conf);
  }

  _init_environment();
  _determine_application_paths();

  return 1;
}

sub _decode_recursively {
  my ($obj) = @_;

  while (my ($key, $value) = each %{ $obj }) {
    if (ref($value) eq 'HASH') {
      _decode_recursively($value);
    } else {
      $obj->{$key} = decode('UTF-8', $value);
    }
  }
}

sub _flat_merge {
  my ($dst, $src) = @_;

  while (my ($key, $value) = each %{ $src }) {
    if (!exists $dst->{$key}) {
      $dst->{$key} = $value;

    } else {
      map { $dst->{$key}->{$_} = $value->{$_} } keys %{ $value };
    }
  }
}

sub _init_environment {
  return if $environment_initialized;

  my %key_map = ( lib  => { name => 'PERL5LIB', append_path => 1 },
                  path => { name => 'PATH',     append_path => 1 },
                );
  my $cfg     = $::lx_office_conf{environment} || {};

  while (my ($key, $value) = each %{ $cfg }) {
    next unless $value;

    my $info = $key_map{$key} || {};
    $key     = $info->{name}  || $key;

    if ($info->{append_path}) {
      $value = ':' . $value unless $value =~ m/^:/ || !$ENV{$key};
      $value = $ENV{$key} . $value if $ENV{$key};
    }

    $ENV{$key} = $value;
  }

  $environment_initialized = 1;
}

sub _determine_application_paths {
  my @paths = grep { $_ } split m/:/, $ENV{PATH};

  foreach my $key (keys %{ $::lx_office_conf{applications} }) {
    my ($program) = split m/\s+/, $::lx_office_conf{applications}->{$key};
    next if $program =~ m|/|;

    foreach my $path (@paths) {
      next unless -f "${path}/${program}";
      $::lx_office_conf{applications}->{$key} = "${path}/" . $::lx_office_conf{applications}->{$key};
      last;
    }
  }
}

1;
