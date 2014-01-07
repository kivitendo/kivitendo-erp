# @tag: custom_variables_delete_via_trigger_2
# @description: Benutzerdefinierte Variablen werden nun via Trigger gelöscht (beim Löschen von Kunden, Lieferanten, Kontaktpersonen, Waren, Dienstleistungen, Erzeugnissen und Projekten).
# @depends: custom_variables_delete_via_trigger

package SL::DBUpgrade2::custom_variables_delete_via_trigger_2;

use utf8;
use strict;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my @queries = (
    #Delete orphaned entries
    q|DELETE FROM custom_variables WHERE (sub_module = '' OR sub_module IS NULL)
                                         AND trans_id NOT IN (SELECT id FROM customer UNION SELECT id FROM vendor)
                                         AND (SELECT module FROM custom_variable_configs WHERE id = config_id) = 'CT'|,
    q|DELETE FROM custom_variables WHERE (sub_module = '' OR sub_module IS NULL)
                                         AND trans_id NOT IN (SELECT id FROM contacts)
                                         AND (SELECT module FROM custom_variable_configs WHERE id = config_id) = 'Contacts'|,
    q|DELETE FROM custom_variables WHERE (sub_module = '' OR sub_module IS NULL)
                                         AND trans_id NOT IN (SELECT id FROM parts)
                                         AND (SELECT module FROM custom_variable_configs WHERE id = config_id) = 'IC'|,
    q|DELETE FROM custom_variables WHERE (sub_module = '' OR sub_module IS NULL)
                                         AND trans_id NOT IN (SELECT id FROM project)
                                         AND (SELECT module FROM custom_variable_configs WHERE id = config_id) = 'Projects'|,

    #Create trigger
    q|CREATE OR REPLACE FUNCTION delete_cv_custom_variables_trigger() RETURNS trigger AS $$
        BEGIN
          DELETE FROM custom_variables WHERE (sub_module = '' OR sub_module IS NULL)
                                         AND trans_id = OLD.id
                                         AND (SELECT module FROM custom_variable_configs WHERE id = config_id) = 'CT';

          RETURN OLD;
        END;
      $$ LANGUAGE plpgsql|,

    q|DROP TRIGGER IF EXISTS delete_cv_custom_variables ON customer|,
    q|DROP TRIGGER IF EXISTS delete_cv_custom_variables ON vendor|,

    q|CREATE TRIGGER delete_cv_custom_variables
      BEFORE DELETE ON customer
      FOR EACH ROW EXECUTE PROCEDURE delete_cv_custom_variables_trigger()|,
    q|CREATE TRIGGER delete_cv_custom_variables
      BEFORE DELETE ON vendor
      FOR EACH ROW EXECUTE PROCEDURE delete_cv_custom_variables_trigger()|,

    #Create trigger
    q|CREATE OR REPLACE FUNCTION delete_contact_custom_variables_trigger() RETURNS trigger AS $$
        BEGIN
          DELETE FROM custom_variables WHERE (sub_module = '' OR sub_module IS NULL)
                                         AND trans_id = OLD.cp_id
                                         AND (SELECT module FROM custom_variable_configs WHERE id = config_id) = 'Contacts';

          RETURN OLD;
        END;
      $$ LANGUAGE plpgsql|,

    q|DROP TRIGGER IF EXISTS delete_contact_custom_variables ON contacts|,

    q|CREATE TRIGGER delete_contact_custom_variables
      BEFORE DELETE ON contacts
      FOR EACH ROW EXECUTE PROCEDURE delete_contact_custom_variables_trigger()|,

    #Create trigger
    q|CREATE OR REPLACE FUNCTION delete_part_custom_variables_trigger() RETURNS trigger AS $$
        BEGIN
          DELETE FROM custom_variables WHERE (sub_module = '' OR sub_module IS NULL)
                                         AND trans_id = OLD.id
                                         AND (SELECT module FROM custom_variable_configs WHERE id = config_id) = 'IC';

          RETURN OLD;
        END;
      $$ LANGUAGE plpgsql|,

    q|DROP TRIGGER IF EXISTS delete_part_custom_variables ON parts|,

    q|CREATE TRIGGER delete_part_custom_variables
      BEFORE DELETE ON parts
      FOR EACH ROW EXECUTE PROCEDURE delete_part_custom_variables_trigger()|,

    #Create trigger
    q|CREATE OR REPLACE FUNCTION delete_project_custom_variables_trigger() RETURNS trigger AS $$
        BEGIN
          DELETE FROM custom_variables WHERE (sub_module = '' OR sub_module IS NULL)
                                         AND trans_id = OLD.id
                                         AND (SELECT module FROM custom_variable_configs WHERE id = config_id) = 'Projects';

          RETURN OLD;
        END;
      $$ LANGUAGE plpgsql|,

    q|DROP TRIGGER IF EXISTS delete_project_custom_variables ON project|,

    q|CREATE TRIGGER delete_project_custom_variables
      BEFORE DELETE ON project
      FOR EACH ROW EXECUTE PROCEDURE delete_project_custom_variables_trigger()|,

    );

  $self->db_query($_) for @queries;

  return 1;
}

1;
