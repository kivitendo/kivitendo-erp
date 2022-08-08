-- @tag: follow_up_done_close_follow_ups_when_order_is_closed
-- @description: Wiedervorlagen schließen, wenn dazugehörige Belege geschlossen werden (nach follow_up_done)
-- @depends: delete_close_follow_ups_when_order_is_deleted_closed

CREATE OR REPLACE FUNCTION follow_up_close_when_oe_closed_trigger()
RETURNS TRIGGER AS $$
  BEGIN
    IF COALESCE(NEW.closed, FALSE) AND NOT COALESCE(OLD.closed, FALSE) THEN
      INSERT INTO follow_up_done (follow_up_id)
        SELECT follow_ups.id
        FROM follow_ups
        LEFT JOIN follow_up_done ON (follow_up_done.follow_up_id = follow_ups.id)
        WHERE follow_up_done.id IS NULL
          AND follow_ups.id IN (
          SELECT follow_up_id
          FROM follow_up_links
          WHERE (trans_id   = NEW.id)
            AND (trans_type IN ('sales_quotation',   'sales_order',    'sales_delivery_order',
                                'request_quotation', 'purchase_order', 'purchase_delivery_order'))
       );
    END IF;

    RETURN NEW;
  END;
$$ LANGUAGE plpgsql;
