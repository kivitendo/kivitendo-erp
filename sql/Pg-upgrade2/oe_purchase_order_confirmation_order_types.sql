-- @tag: oe_purchase_order_confirmation_order_types
-- @description: order_types-Eintrag für Lieferantenauftragsbesätigung (purchase_order_confirmation)
-- @depends: order_type
-- @ignore: 0

ALTER TYPE order_types ADD VALUE IF NOT EXISTS 'purchase_order_confirmation';
