package SL::Presenter::CustomVariableConfig;

use strict;

use SL::Presenter::EscapedText qw(escape is_escaped);
use SL::Locale::String qw(t8);

use Exporter qw(import);
our @EXPORT_OK = qw(cvar_config_description_with_module);

our %t8 = (
  CT                => t8('Customers and vendors'),
  Contacts          => t8('Contact persons'),
  IC                => t8('Parts, services and assemblies'),
  Projects          => t8('Projects'),
  RequirementSpecs  => t8('Requirement Specs'),
  ShipTo            => t8('Shipping Address'),
);


sub cvar_config_description_with_module {
  my ($cvar_config) = @_;

  my $module = $t8{$cvar_config->module};
  my $description = $cvar_config->description;

  escape("($module) $description");
}

sub description_with_module {
  goto &cvar_config_description_with_module;
}


1;
