# @tag: custom_variables_delete_via_trigger_2
# @description: Benutzerdefinierte Variablen werden nun via Trigger gelöscht (beim Löschen von Kunden, Lieferanten, Kontaktpersonen, Waren, Dienstleistungen, Erzeugnissen und Projekten).
# @depends: custom_variables_delete_via_trigger

package SL::DBUpgrade2::custom_variables_delete_via_trigger_2;

use utf8;
use strict;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  # This script is intentionally empty, because there is another upgrade script
  # which provides this functionality.

  return 1;
}

1;
