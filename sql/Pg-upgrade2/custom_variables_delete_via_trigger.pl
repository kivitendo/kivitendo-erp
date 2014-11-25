# @tag: custom_variables_delete_via_trigger
# @description: Benutzerdefinierte Variablen werden nun via Trigger gelöscht.
# @depends: custom_variable_configs_column_type_text custom_variables custom_variables_indices custom_variables_indices_2 custom_variables_parts_services_assemblies custom_variables_sub_module_not_null custom_variables_valid

package SL::DBUpgrade2::custom_variables_delete_via_trigger;

use utf8;
use strict;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  # This script is intentionally empty, because there is another upgrade script
  # which provides this functionality.

  return 1;
}

1;
