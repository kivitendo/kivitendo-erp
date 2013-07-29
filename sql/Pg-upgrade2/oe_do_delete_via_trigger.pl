# @tag: oe_do_delete_via_trigger
# @description: Aus oe/delivery_orders via Trigger löschen können
# @depends: orderitems_delivery_order_items_invoice_foreign_keys

package SL::DBUpgrade2::oe_do_delete_via_trigger;

use utf8;
use strict;

use parent qw(SL::DBUpgrade2::Base);

sub run {
  my ($self) = @_;

  $self->drop_constraints(table => $_) for qw(periodic_invoices periodic_invoices_configs orderitems delivery_order_items delivery_order_items_stock);

  my @queries = (
    q|ALTER TABLE periodic_invoices          ADD CONSTRAINT periodic_invoices_ar_id_fkey                           FOREIGN KEY (ar_id)                  REFERENCES ar                        (id) ON DELETE CASCADE|,
    q|ALTER TABLE periodic_invoices          ADD CONSTRAINT periodic_invoices_config_id_fkey                       FOREIGN KEY (config_id)              REFERENCES periodic_invoices_configs (id) ON DELETE CASCADE|,

    q|ALTER TABLE periodic_invoices_configs  ADD CONSTRAINT periodic_invoices_configs_ar_chart_id_fkey             FOREIGN KEY (ar_chart_id)            REFERENCES chart                     (id) ON DELETE RESTRICT|,
    q|ALTER TABLE periodic_invoices_configs  ADD CONSTRAINT periodic_invoices_configs_oe_id_fkey                   FOREIGN KEY (oe_id)                  REFERENCES oe                        (id) ON DELETE CASCADE|,
    q|ALTER TABLE periodic_invoices_configs  ADD CONSTRAINT periodic_invoices_configs_printer_id_fkey              FOREIGN KEY (printer_id)             REFERENCES printers                  (id) ON DELETE SET NULL|,

    q|ALTER TABLE orderitems                 ADD CONSTRAINT orderitems_parts_id_fkey                               FOREIGN KEY (parts_id)               REFERENCES parts                     (id) ON DELETE RESTRICT|,
    q|ALTER TABLE orderitems                 ADD CONSTRAINT orderitems_price_factor_id_fkey                        FOREIGN KEY (price_factor_id)        REFERENCES price_factors             (id) ON DELETE RESTRICT|,
    q|ALTER TABLE orderitems                 ADD CONSTRAINT orderitems_pricegroup_id_fkey                          FOREIGN KEY (pricegroup_id)          REFERENCES pricegroup                (id) ON DELETE RESTRICT|,
    q|ALTER TABLE orderitems                 ADD CONSTRAINT orderitems_project_id_fkey                             FOREIGN KEY (project_id)             REFERENCES project                   (id) ON DELETE SET NULL|,
    q|ALTER TABLE orderitems                 ADD CONSTRAINT orderitems_trans_id_fkey                               FOREIGN KEY (trans_id)               REFERENCES oe                        (id) ON DELETE CASCADE|,

    q|ALTER TABLE delivery_order_items       ADD CONSTRAINT delivery_order_items_delivery_order_id_fkey            FOREIGN KEY (delivery_order_id)      REFERENCES delivery_orders           (id) ON DELETE CASCADE|,
    q|ALTER TABLE delivery_order_items       ADD CONSTRAINT delivery_order_items_parts_id_fkey                     FOREIGN KEY (parts_id)               REFERENCES parts                     (id) ON DELETE RESTRICT|,
    q|ALTER TABLE delivery_order_items       ADD CONSTRAINT delivery_order_items_price_factor_id_fkey              FOREIGN KEY (price_factor_id)        REFERENCES price_factors             (id) ON DELETE RESTRICT|,
    q|ALTER TABLE delivery_order_items       ADD CONSTRAINT delivery_order_items_pricegroup_id_fkey                FOREIGN KEY (pricegroup_id)          REFERENCES pricegroup                (id) ON DELETE RESTRICT|,
    q|ALTER TABLE delivery_order_items       ADD CONSTRAINT delivery_order_items_project_id_fkey                   FOREIGN KEY (project_id)             REFERENCES project                   (id) ON DELETE SET NULL|,

    q|ALTER TABLE delivery_order_items_stock ADD CONSTRAINT delivery_order_items_stock_bin_id_fkey                 FOREIGN KEY (bin_id)                 REFERENCES bin                       (id) ON DELETE RESTRICT|,
    q|ALTER TABLE delivery_order_items_stock ADD CONSTRAINT delivery_order_items_stock_delivery_order_item_id_fkey FOREIGN KEY (delivery_order_item_id) REFERENCES delivery_order_items      (id) ON DELETE CASCADE|,
    q|ALTER TABLE delivery_order_items_stock ADD CONSTRAINT delivery_order_items_stock_warehouse_id_fkey           FOREIGN KEY (warehouse_id)           REFERENCES warehouse                 (id) ON DELETE RESTRICT|,

    q|CREATE OR REPLACE FUNCTION oe_before_delete_trigger() RETURNS trigger AS $$
        BEGIN
          DELETE FROM status WHERE trans_id = OLD.id;
          DELETE FROM shipto WHERE (trans_id = OLD.id) AND (module = 'OE');

          RETURN OLD;
        END;
      $$ LANGUAGE plpgsql|,

    q|DROP TRIGGER IF EXISTS delete_oe_dependencies ON oe|,

    q|CREATE TRIGGER delete_oe_dependencies
      BEFORE DELETE ON oe
      FOR EACH ROW EXECUTE PROCEDURE oe_before_delete_trigger()|,

    q|CREATE OR REPLACE FUNCTION delivery_orders_before_delete_trigger() RETURNS trigger AS $$
        BEGIN
          DELETE FROM status                     WHERE trans_id = OLD.id;
          DELETE FROM delivery_order_items_stock WHERE delivery_order_item_id IN (SELECT id FROM delivery_order_items WHERE delivery_order_id = OLD.id);
          DELETE FROM shipto                     WHERE (trans_id = OLD.id) AND (module = 'OE');

          RETURN OLD;
        END;
      $$ LANGUAGE plpgsql|,

    q|DROP TRIGGER IF EXISTS delete_delivery_orders_dependencies ON delivery_orders|,

    q|CREATE TRIGGER delete_delivery_orders_dependencies
      BEFORE DELETE ON delivery_orders
      FOR EACH ROW EXECUTE PROCEDURE delivery_orders_before_delete_trigger()|);

  $self->db_query($_) for @queries;

  return 1;
}

1;
