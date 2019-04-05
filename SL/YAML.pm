package SL::YAML;

use strict;
use warnings;

sub _choose_yaml_module {
  return 'YAML::XS' if $INC{'YAML/XS.pm'};
  return 'YAML'     if $INC{'YAML.pm'};

  my @err;

  return 'YAML::XS' if eval { require YAML::XS; 1; };
  push @err, "Error loading YAML::XS: $@";

  return 'YAML' if eval { require YAML; 1; };
  push @err, "Error loading YAML: $@";

  die join("\n", "Couldn't load a YAML module:", @err);
}

BEGIN {
  our $YAML_Class = _choose_yaml_module();
  $YAML_Class->import(qw(Dump Load DumpFile LoadFile));
}

sub YAML { our $YAML_Class }

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::YAML - A thin wrapper around YAML::XS and YAML

=head1 SYNOPSIS

    use SL::YAML;

    my $menu_data = SL::YAML::LoadFile("menus/user/00-erp.yml");

=head1 OVERVIEW

This is a thin wrapper around the YAML::XS and YAML modules. It'll
prefer loading YAML::XS if that's found and will fallback to YAML
otherwise. It only provides the four functions C<Dump>, C<Load>,
C<DumpFile> and C<LoadFile> — just enough to get by for kivitendo.

The functions are direct imports from the imported module. Please see
the documentation for YAML::XS or YAML for details.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
