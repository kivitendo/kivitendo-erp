# @tag: custom_variables_delete_via_trigger
# @description: Benutzerdefinierte Variablen werden nun via Trigger gelöscht.
# @depends: custom_variable_configs_column_type_text custom_variables custom_variables_indices custom_variables_indices_2 custom_variables_parts_services_assemblies custom_variables_sub_module_not_null custom_variables_valid

package SL::DBUpgrade2::custom_variables_delete_via_trigger;

use utf8;
use strict;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  my @queries = (
    #Delete orphaned entries
    q|DELETE FROM custom_variables WHERE sub_module = 'orderitems' AND trans_id NOT IN (SELECT id FROM orderitems)|,
    q|DELETE FROM custom_variables WHERE sub_module = 'delivery_order_items' AND trans_id NOT IN (SELECT id FROM delivery_order_items)|,
    q|DELETE FROM custom_variables WHERE sub_module = 'invoice' AND trans_id NOT IN (SELECT id FROM invoice)|,

    #Create trigger
    q|CREATE OR REPLACE FUNCTION orderitems_before_delete_trigger() RETURNS trigger AS $$
        BEGIN
          DELETE FROM custom_variables WHERE sub_module = 'orderitems' AND trans_id = OLD.id;

          RETURN OLD;
        END;
      $$ LANGUAGE plpgsql|,

    q|DROP TRIGGER IF EXISTS delete_orderitems_dependencies ON orderitems|,

    q|CREATE TRIGGER delete_orderitems_dependencies
      BEFORE DELETE ON orderitems
      FOR EACH ROW EXECUTE PROCEDURE orderitems_before_delete_trigger()|,

    q|CREATE OR REPLACE FUNCTION delivery_order_items_before_delete_trigger() RETURNS trigger AS $$
        BEGIN
          DELETE FROM custom_variables WHERE sub_module = 'delivery_order_items' AND trans_id = OLD.id;

          RETURN OLD;
        END;
      $$ LANGUAGE plpgsql|,

    q|DROP TRIGGER IF EXISTS delete_delivery_order_items_dependencies ON delivery_order_items|,

    q|CREATE TRIGGER delete_delivery_order_items_dependencies
      BEFORE DELETE ON delivery_order_items
      FOR EACH ROW EXECUTE PROCEDURE delivery_order_items_before_delete_trigger()|,

    q|CREATE OR REPLACE FUNCTION invoice_before_delete_trigger() RETURNS trigger AS $$
        BEGIN
          DELETE FROM custom_variables WHERE sub_module = 'invoice' AND trans_id = OLD.id;

          RETURN OLD;
        END;
      $$ LANGUAGE plpgsql|,

    q|DROP TRIGGER IF EXISTS delete_invoice_dependencies ON invoice|,

    q|CREATE TRIGGER delete_invoice_dependencies
      BEFORE DELETE ON invoice
      FOR EACH ROW EXECUTE PROCEDURE invoice_before_delete_trigger()|
    );

  $self->db_query($_) for @queries;

  return 1;
}

1;
