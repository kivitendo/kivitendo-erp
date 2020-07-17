-- @tag: konjunkturpaket_2020
-- @description: Anpassung der Steuersätze für 16%/5% für Deutsche DATEV-Kontenrahmen SKR03 und SKR04
-- @depends: release_3_5_5 konjunkturpaket_2020_SKR03 konjunkturpaket_2020_SKR04
-- @ignore: 0

-- begin;

DO $$

DECLARE
  -- variables for main taxkey creation loop, not all are needed
  _chart_id int;
  _accno text;
  _description text;
  _startdates date[];
  _tax_ids int[];
  _taxkeyentry_id int[];
  _taxkey_ids int[];
  _rates numeric[];
  _taxcharts text[];

  current_taxkey record;
  new_taxkey     record;
  _rate          numeric;
  _tax           record; -- store the new tax we need to assign to a chart, e.g. 5%, 16%

  _taxkey    int;
  _old_rate  numeric;
  _old_chart text;
  _new_chart numeric;
  _new_rate  text;

  _tax_conversion record;


BEGIN

IF ( select coa from defaults ) ~ 'DATEV' THEN

--begin;
--delete from taxkeys where startdate >= '2020-01-01';

--  create temp table temp_taxkey_conversions (taxkey int, old_rate numeric, new_rate numeric, tax_chart_skr03 text, tax_chart_skr04 text);
--  insert into temp_taxkey_conversions (taxkey, old_rate, new_rate, tax_chart_skr03, tax_chart_skr04) values
----    (2, 0.07, 0.05, '1773', '3803'),  -- 5% case is handled by skr03 case -> needs different automatic chart: 1773 Umsatzsteuer 5% (SKR03, instead of 1771 Umsatzsteuer 7%) or 3803 Umsatzsteuer 5%
--    -- (8, 0.07, 0.05, null, null),
--    -- (3, 0.19, 0.16, null, null),
--    -- (9, 0.19, 0.16, null, null),
--   (13, 0.19, 0.16, null, null);


  create temp table temp_taxkey_conversions (taxkey int, old_rate numeric, old_chart text, new_rate numeric, new_chart text);

  IF ( select coa from defaults ) = 'Germany-DATEV-SKR03EU' THEN
    insert into temp_taxkey_conversions (taxkey, old_rate, old_chart, new_rate, new_chart)
    values (9, 0.19, '1576', 0.16, '1575'),
           (8, 0.07, '1571', 0.05, '1568'),
           (3, 0.19, '1776', 0.16, '1575'),
           (2, 0.07, '1771', 0.05, '1775');
         --1776 => 19%
         --1775 => 16%
         --1775 =>  5%
         --1771 =>  7%
         --
         --VSt:
         --1576 => 19%
         --1575 => 16%
         --1568 =>  5%
         --1571 =>  7%

  ELSE  -- Germany-DATEV-SKR04EU
    insert into temp_taxkey_conversions (taxkey, old_rate, old_chart, new_rate, new_chart)
    values (9, 0.19, '1406', 0.16, '1405'),
           (8, 0.07, '1401', 0.05, '1403'),
           (3, 0.19, '3806', 0.16, '3805'),
           (2, 0.07, '3801', 0.05, '3803');
  END IF;

  FOR _chart_id, _accno, _description, _startdates, _tax_ids, _taxkeyentry_id, _taxkey_ids, _rates, _taxcharts IN

      select c.id as chart_id,
             c.accno,
             c.description,
             array_agg(t.startdate order by t.startdate desc) as startdates,
             array_agg(t.tax_id    order by t.startdate desc) as tax_ids,
             array_agg(t.id        order by t.startdate desc) as taxkeyentry_id,
             array_agg(t.taxkey_id order by t.startdate desc) as taxkey_ids,
             array_agg(tax.rate    order by t.startdate desc) as rates,
             array_agg(tc.accno    order by t.startdate desc) as taxcharts
        from taxkeys t
             left join chart c  on (c.id         = t.chart_id)
             left join tax      on (tax.id       = t.tax_id)
             left join chart tc on (tax.chart_id = tc.id)
       where t.taxkey_id in (select taxkey from temp_taxkey_conversions)  -- 2, 3, 8, 9
             -- and (c.accno = '8400') -- debug
             -- you can't filter for valid taxrates 19% or 7% here, as that would still leave the 16% rates as the current one
    group by c.id,
             c.accno,
             c.description
    order by c.accno

    -- example output for human debugging:
    --  chart_id | accno |     description     |       startdates        |  tax_ids  | taxkeyentry_id | taxkey_ids |       rates       |  taxcharts
    -- ----------+-------+---------------------+-------------------------+-----------+----------------+------------+-------------------+-------------
    --       184 | 8400  | Erlöse 16%/19% USt. | {2007-01-01,1970-01-01} | {777,379} | {793,676}      | {3,3}      | {0.19000,0.16000} | {1776,1775}

  -- each chart with one of the applicable taxkeys should receive two new entries, one starting on 01.07.2020, the other on 01.01.2021
  LOOP
    -- 1. create new taxkey entry on 2020-07-01, using the active taxkey on 2020-06-30 as a template, but linking to a tax with a different tax rate
    -- 2. create new taxkey entry on 2021-01-01, using the active taxkey on 2020-06-30 as a template, but with the new date


    -- fetch tax information for 2020-06-30, one day before the change, this should also be the first entry in the ordered array aggregates
    -- this can be used as the template for the reset on 2021-01-01

    -- raise notice 'looking up current taxkey for chart % and taxkey %', (select accno from chart where id = _chart_id), _taxkey_ids[1];
    select into current_taxkey tk.*, t.rate, t.taxkey
           from taxkeys tk
                left join tax t on (t.id = tk.tax_id)
          where     tk.taxkey_id = _taxkey_ids[1] -- assume taxkey never changed, use the first one
                and tk.chart_id = _chart_id
                and tk.startdate <= '2020-06-30'
       order by tk.startdate desc
          limit 1;
    -- RAISE NOTICE 'found current_taxkey = %', current_taxkey;
    IF current_taxkey is null then continue; end if;
    -- RAISE NOTICE 'found chart % with current startdate % and taxkey % (current: %), rate = %', _accno, current_taxkey.startdate, _taxkey_ids[1], current_taxkey.taxkey, current_taxkey.rate;

    -- RAISE NOTICE 'current_taxkey = %', current_taxkey;
    -- RAISE NOTICE 'looking up tkc for chart_id % and taxkey  %', _chart_id, current_taxkey.taxkey;

    select into _taxkey, _old_rate, _old_chart, _new_chart, _new_rate
                 taxkey,  old_rate,  old_chart,  new_chart,  new_rate
    from temp_taxkey_conversions tkc
    where     tkc.taxkey    = current_taxkey.taxkey
          and tkc.old_rate = current_taxkey.rate;
          -- and tkc.new_chart = current_taxkey.new_chart;

    -- raise notice '_old_rate = %, _new_rate = %', _old_rate, _new_rate;

    -- don't do anything if current taxrate is 0, which might be the case for taxkey 13, if they were configured in that way
    IF current_taxkey.rate != 0 THEN  -- debug

      -- _rate := null;

      -- IF current_taxkey.rate = 0.19 THEN _rate := 0.16; END IF;
      -- IF current_taxkey.rate = 0.07 THEN _rate := 0.05; END IF;
      IF _old_rate is NULL THEN

        -- option A: ignore rates which don't make sense, useful for upgrade mode
        -- option B: throw exception, useful for manually testing script

        -- A:
        -- if the rate on 2020-06-30 is neither 19 or 7, simply ignore it, it is obviously not configured correctly
        -- This is the case for SKR03 and chart 8315 (taxkey 13)
        -- It might be better to throw an exception, however then the test cases don't run. Or just fix the chart via an upgrade script!
        CONTINUE;

        -- B:
        -- RAISE EXCEPTION 'illegal current taxrate % on 2020-06-30 (startdate = %) for chart % with taxkey %, should be either 0.19 or 0.07',
        --                 current_taxkey.rate, current_taxkey.startdate,
        --                 (select accno from chart where id = current_taxkey.chart_id),
        --                 current_taxkey.taxkey_id;
      END IF;
      -- RAISE NOTICE 'current_taxkey.rate = %, desired rate = %, looking for taxkey_id %', current_taxkey.rate, _rate, _taxkey_ids[1];

      -- if a chart was created way after 2007 and only ever configured for
      -- 19%, never 16%, which is the case for SKR04 and taxkey 13, there will only be 3
      -- taxkeys per chart after adding the two new ones

      -- RAISE NOTICE 'searching for tax with taxkey % and rate %', _taxkey_ids[1], _rate;
      select into _tax
                  *
             from tax
            where tax.rate = _old_rate
                  and tax.taxkey = _taxkey_ids[1]
         order by itime desc
            limit 1; -- look up tax with same taxkey but corresponding rate. As there will now be two entries for e.g. taxkey 9 with rate of 0.16, the old pre-2007 entry and the new 2020-entry. They can only be differentiated by their (automatic tax) chart_id, or during this upgrade script, via itime, use the later one
                     -- this also assumes taxkeys never change
      -- RAISE NOTICE 'tax = %', _tax;

      -- insert into taxkeys (chart_id,                 tax_id,   taxkey_id,                pos_ustva,    startdate)
      --              values ( (select id from chart where accno = 'kkkkgtkttttkk current_taxkey.chart_id, _tax.id, _tax.taxkey, current_taxkey.pos_ustva, '2020-07-01');
    END IF;

    -- raise notice 'inserting taxkey';
    insert into taxkeys (chart_id,                                tax_id,                taxkey_id,                pos_ustva, startdate   )
                 values (_chart_id,
                         (select id from tax where taxkey = current_taxkey.taxkey and rate = _new_rate::numeric),
                         current_taxkey.taxkey, -- 2, 3, 8, 9
                         current_taxkey.pos_ustva, '2020-07-01');

    -- finally insert a copy of the taxkey on 2020-06-30 with the new startdate 2021-01-01, thereby resetting the tax rates again
    insert into taxkeys (chart_id, tax_id, taxkey_id, pos_ustva, startdate)
                 values (_chart_id,
                         current_taxkey.tax_id,
                         current_taxkey.taxkey,
                         current_taxkey.pos_ustva, '2021-01-01');

    -- RAISE NOTICE 'inserted 2 taxkeys for chart % with taxkey %', (select accno from chart where id = current_taxkey.chart_id), current_taxkey.taxkey_id;
  END LOOP;  --

  drop table temp_taxkey_conversions;

END IF;

END $$;

-- select * from taxkeys where startdate >= '2020-01-01';
-- rollback;
