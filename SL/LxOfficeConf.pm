package SL::LxOfficeConf;

use strict;

use Config::Std;
use Encode;

my $environment_initialized;

sub read {
  my ($class, $file_name) = @_;

  read_config 'config/lx_office.conf.default' => %::lx_office_conf;
  _decode_recursively(\%::lx_office_conf);

  $file_name ||= 'config/lx_office.conf';

  if (-f $file_name) {
    read_config $file_name => my %local_conf;
    _decode_recursively(\%local_conf);
    _flat_merge(\%::lx_office_conf, \%local_conf);
  }

  _init_environment();
  _determine_application_paths();
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
      $value = $ENV{$key} . $value;
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
