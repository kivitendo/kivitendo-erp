-- @tag: oe_sales_receipt_order_types
-- @description: order_types-Eintrag für geparkte Quittung (sales_receipt)
-- @depends: release_3_9_0
-- @ignore: 0

ALTER TYPE order_types ADD VALUE IF NOT EXISTS 'sales_receipt';
