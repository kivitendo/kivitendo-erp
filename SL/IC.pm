#=====================================================================
# LX-Office ERP
# Copyright (C) 2004
# Based on SQL-Ledger Version 2.1.9
# Web http://www.lx-office.org
#
#=====================================================================
# SQL-Ledger Accounting
# Copyright (C) 2001
#
#  Author: Dieter Simader
#   Email: dsimader@sql-ledger.org
#     Web: http://www.sql-ledger.org
#
#  Contributors:
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1335, USA.
#======================================================================
#
# Inventory Control backend
#
#======================================================================

package IC;

use Data::Dumper;
use List::MoreUtils qw(all any uniq);
use YAML;

use SL::CVar;
use SL::DBUtils;
use SL::HTML::Restrict;
use SL::TransNumber;
use SL::Util qw(trim);
use SL::DB;
use SL::Presenter::Part qw(type_abbreviation classification_abbreviation separate_abbreviation);
use Carp;

use strict;

sub retrieve_buchungsgruppen {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my ($query, $sth);

  my $dbh = $form->get_standard_dbh;

  # get buchungsgruppen
  $query = qq|SELECT id, description FROM buchungsgruppen ORDER BY sortkey|;
  $form->{BUCHUNGSGRUPPEN} = selectall_hashref_query($form, $dbh, $query);

  $main::lxdebug->leave_sub();
}

sub assembly_item {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;

  my $i = $form->{assembly_rows};
  my $var;
  my $where = qq|1 = 1|;
  my @values;

  my %columns = ("partnumber" => "p", "description" => "p", "partsgroup" => "pg");

  while (my ($column, $table) = each(%columns)) {
    next unless ($form->{"${column}_$i"});
    $where .= qq| AND ${table}.${column} ILIKE ?|;
    push(@values, like($form->{"${column}_$i"}));
  }

  if ($form->{id}) {
    $where .= qq| AND NOT (p.id = ?)|;
    push(@values, conv_i($form->{id}));
  }

  # Search for part ID overrides all other criteria.
  if ($form->{"id_${i}"}) {
    $where  = qq|p.id = ?|;
    @values = ($form->{"id_${i}"});
  }

  if ($form->{partnumber}) {
    $where .= qq| ORDER BY p.partnumber|;
  } else {
    $where .= qq| ORDER BY p.description|;
  }

  my $query =
    qq|SELECT p.id, p.partnumber, p.description, p.sellprice,
       p.classification_id,
       p.weight, p.onhand, p.unit, pg.partsgroup, p.lastcost,
       p.price_factor_id, pfac.factor AS price_factor, p.notes as longdescription
       FROM parts p
       LEFT JOIN partsgroup pg ON (p.partsgroup_id = pg.id)
       LEFT JOIN price_factors pfac ON pfac.id = p.price_factor_id
       WHERE $where|;
  $form->{item_list} = selectall_hashref_query($form, SL::DB->client->dbh, $query, @values);

  $main::lxdebug->leave_sub();
}

#
# Report for Wares.
# Warning, deep magic ahead.
# This function gets all parts from the database according to the filters specified
#
# specials:
#   sort revers  - sorting field + direction
#   top100
#
# simple filter strings (every one of those also has a column flag prefixed with 'l_' associated):
#   partnumber ean description partsgroup microfiche drawing
#
# column flags:
#   l_partnumber l_description l_listprice l_sellprice l_lastcost l_priceupdate l_weight l_unit l_rop l_image l_drawing l_microfiche l_partsgroup
#   l_warehouse  l_bin
#
# exclusives:
#   itemstatus  = active | onhand | short | obsolete | orphaned
#   searchitems = part | assembly | service
#
# joining filters:
#   make model                               - makemodel
#   serialnumber transdatefrom transdateto   - invoice/orderitems
#   warehouse                                - warehouse
#   bin                                      - bin
#
# binary flags:
#   bought sold onorder ordered rfq quoted   - aggreg joins with invoices/orders
#   l_linetotal l_subtotal                   - aggreg joins to display totals (complicated) - NOT IMPLEMENTED here, implementation at frontend
#   l_soldtotal                              - aggreg join to display total of sold quantity
#   onhand                                   - as above, but masking the simple itemstatus results (doh!)
#   short                                    - NOT IMPLEMENTED as form filter, only as itemstatus option
#   l_serialnumber                           - belonges to serialnumber filter
#   l_deliverydate                           - displays deliverydate is sold etc. flags are active
#   l_soldtotal                              - aggreg join to display total of sold quantity, works as long as there's no bullshit in soldtotal
#
# not working:
#   onhand                                   - as above, but masking the simple itemstatus results (doh!)
#   warehouse onhand
#   search by overrides of description
#   soldtotal drops option default warehouse and bin
#   soldtotal can not work if there are no documents checked
#
# disabled sanity checks and changes:
#  - searchitems = assembly will no longer disable bought
#  - searchitems = service  will no longer disable make and model, although services don't have make/model, it doesn't break the query
#  - itemstatus  = orphaned will no longer disable onhand short bought sold onorder ordered rfq quoted transdate[from|to]
#  - itemstatus  = obsolete will no longer disable onhand, short
#  - allow sorting by ean
#  - serialnumber filter also works if l_serialnumber isn't ticked
#  - sorting will now change sorting if the requested sorting column isn't checked and doesn't get checked as a side effect
#
sub all_parts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form) = @_;
  my $dbh = $form->get_standard_dbh($myconfig);

  # sanity backend check
  croak "Cannot combine soldtotal with default bin or default warehouse" if ($form->{l_soldtotal} && ($form->{l_bin} || $form->{l_warehouse}));

  $form->{parts}     = +{ };
  $form->{soldtotal} = undef if $form->{l_soldtotal}; # security fix. top100 insists on putting strings in there...

  my @simple_filters       = qw(partnumber ean description partsgroup microfiche drawing onhand);
  my @project_filters      = qw(projectnumber projectdescription);
  my @makemodel_filters    = qw(make model);
  my @invoice_oi_filters   = qw(serialnumber soldtotal);
  my @apoe_filters         = qw(transdate);
  my @like_filters         = (@simple_filters, @invoice_oi_filters);
  my @all_columns          = (@simple_filters, @makemodel_filters, @apoe_filters, @project_filters, qw(serialnumber));
  my @simple_l_switches    = (@all_columns, qw(notes listprice sellprice lastcost priceupdate weight unit rop image shop insertdate));
  my %no_simple_l_switches = (warehouse => 'wh.description as warehouse', bin => 'bin.description as bin');
  my @oe_flags             = qw(bought sold onorder ordered rfq quoted);
  my @qsooqr_flags         = qw(invnumber ordnumber quonumber trans_id name module qty);
  my @deliverydate_flags   = qw(deliverydate);
#  my @other_flags          = qw(onhand); # ToDO: implement these
#  my @inactive_flags       = qw(l_subtotal short l_linetotal);

  my @select_tokens = qw(id factor part_type classification_id);
  my @where_tokens  = qw(1=1);
  my @group_tokens  = ();
  my @bind_vars     = ();
  my %joins_needed  = ();

  my %joins = (
    partsgroup => 'LEFT JOIN partsgroup pg      ON (pg.id       = p.partsgroup_id)',
    makemodel  => 'LEFT JOIN makemodel mm       ON (mm.parts_id = p.id)',
    pfac       => 'LEFT JOIN price_factors pfac ON (pfac.id     = p.price_factor_id)',
    invoice_oi =>
      q|LEFT JOIN (
         SELECT parts_id, description, serialnumber, trans_id, unit, sellprice, qty,          assemblyitem,         deliverydate, 'invoice'    AS ioi, project_id, id FROM invoice UNION
         SELECT parts_id, description, serialnumber, trans_id, unit, sellprice, qty, FALSE AS assemblyitem, NULL AS deliverydate, 'orderitems' AS ioi, project_id, id FROM orderitems
       ) AS ioi ON ioi.parts_id = p.id|,
    apoe       =>
      q|LEFT JOIN (
         SELECT id, transdate, 'ir' AS module, ordnumber, quonumber,         invnumber, FALSE AS quotation, NULL AS customer_id,         vendor_id,    NULL AS deliverydate, globalproject_id, 'invoice'    AS ioi FROM ap UNION
         SELECT id, transdate, 'is' AS module, ordnumber, quonumber,         invnumber, FALSE AS quotation,         customer_id, NULL AS vendor_id,            deliverydate, globalproject_id, 'invoice'    AS ioi FROM ar UNION
         SELECT id, transdate, 'oe' AS module, ordnumber, quonumber, NULL AS invnumber,          quotation,         customer_id,         vendor_id, reqdate AS deliverydate, globalproject_id, 'orderitems' AS ioi FROM oe
       ) AS apoe ON ((ioi.trans_id = apoe.id) AND (ioi.ioi = apoe.ioi))|,
    cv         =>
      q|LEFT JOIN (
           SELECT id, name, 'customer' AS cv FROM customer UNION
           SELECT id, name, 'vendor'   AS cv FROM vendor
         ) AS cv ON cv.id = apoe.customer_id OR cv.id = apoe.vendor_id|,
    mv         => 'LEFT JOIN vendor AS mv ON mv.id = mm.make',
    project    => 'LEFT JOIN project AS pj ON pj.id = COALESCE(ioi.project_id, apoe.globalproject_id)',
    warehouse  => 'LEFT JOIN warehouse AS wh ON wh.id = p.warehouse_id',
    bin        => 'LEFT JOIN bin ON bin.id = p.bin_id',
  );
  my @join_order = qw(partsgroup makemodel mv invoice_oi apoe cv pfac project warehouse bin);

  my %table_prefix = (
     deliverydate => 'apoe.', serialnumber => 'ioi.',
     transdate    => 'apoe.', trans_id     => 'ioi.',
     module       => 'apoe.', name         => 'cv.',
     ordnumber    => 'apoe.', make         => 'mm.',
     quonumber    => 'apoe.', model        => 'mm.',
     invnumber    => 'apoe.', partsgroup   => 'pg.',
     lastcost     => 'p.',  , soldtotal    => ' ',
     factor       => 'pfac.', projectnumber => 'pj.',
     'SUM(ioi.qty)' => ' ',   projectdescription => 'pj.',
     description  => 'p.',
     qty          => 'ioi.',
     serialnumber => 'ioi.',
     quotation    => 'apoe.',
     cv           => 'cv.',
     "ioi.id"     => ' ',
     "ioi.ioi"    => ' ',
  );

  # if the join condition in these blocks are met, the column
  # of the specified table will gently override (coalesce actually) the original value
  # use it to conditionally coalesce values from subtables
  my @column_override = (
    #  column name,   prefix,  joins_needed,  nick name (in case column is named like another)
    [ 'description',  'ioi.',  'invoice_oi'  ],
    [ 'deliverydate', 'ioi.',  'invoice_oi'  ],
    [ 'transdate',    'apoe.', 'apoe'        ],
    [ 'unit',         'ioi.',  'invoice_oi'  ],
    [ 'sellprice',    'ioi.',  'invoice_oi'  ],
  );

  # careful with renames. these are HARD, and any filters done on the original column will break
  my %renamed_columns = (
    'factor'       => 'price_factor',
    'SUM(ioi.qty)' => 'soldtotal',
    'ioi.id'       => 'ioi_id',
    'ioi.ioi'      => 'ioi',
    'projectdescription' => 'projectdescription',
    'insertdate'   => 'insertdate',
  );

  my %real_column = (
    projectdescription => 'description',
    insertdate         => 'itime::DATE',
  );

  if ($form->{l_assembly} && $form->{l_lastcost}) {
    @simple_l_switches = grep { $_ ne 'lastcost' } @simple_l_switches;
  }

  my $make_token_builder = sub {
    my $joins_needed = shift;
    sub {
      my ($nick, $alias) = @_;
      my ($col) = $real_column{$nick} || $nick;
      my @coalesce_tokens =
        map  { ($_->[1] || 'p.') . $_->[0] }
        grep { !$_->[2] || $joins_needed->{$_->[2]} }
        grep { ($_->[3] || $_->[0]) eq $nick }
        @column_override, [ $col, $table_prefix{$nick}, undef , $nick ];

      my $coalesce = scalar @coalesce_tokens > 1;
      return ($coalesce
        ? sprintf 'COALESCE(%s)', join ', ', @coalesce_tokens
        : shift                              @coalesce_tokens)
        . ($alias && ($coalesce || $renamed_columns{$nick})
        ?  " AS " . ($renamed_columns{$nick} || $nick)
        : '');
    }
  };

  #===== switches and simple filters ========#

  # special case transdate
  if (grep { trim($form->{$_}) } qw(transdatefrom transdateto)) {
    $form->{"l_transdate"} = 1;
    push @select_tokens, 'transdate';
    for (qw(transdatefrom transdateto)) {
      my $value = trim($form->{$_});
      next unless $value;
      push @where_tokens, sprintf "transdate %s ?", /from$/ ? '>=' : '<=';
      push @bind_vars,    $value;
    }
  }

  # special case smart search
  if ($form->{all}) {
    $form->{"l_$_"}       = 1 for qw(partnumber description unit sellprice lastcost linetotal);
    $form->{l_service}    = 1 if $form->{searchitems} eq 'service'    || $form->{searchitems} eq '';
    $form->{l_assembly}   = 1 if $form->{searchitems} eq 'assembly'   || $form->{searchitems} eq '';
    $form->{l_part}       = 1 if $form->{searchitems} eq 'part'       || $form->{searchitems} eq '';
    $form->{l_assortment} = 1 if $form->{searchitems} eq 'assortment' || $form->{searchitems} eq '';
    push @where_tokens, "p.partnumber ILIKE ? OR p.description ILIKE ?";
    push @bind_vars,    (like($form->{all})) x 2;
  }

  # special case insertdate
  if (grep { trim($form->{$_}) } qw(insertdatefrom insertdateto)) {
    $form->{"l_insertdate"} = 1;
    push @select_tokens, 'insertdate';

    my $token_builder = $make_token_builder->();
    my $token = $token_builder->('insertdate');

    for (qw(insertdatefrom insertdateto)) {
      my $value = trim($form->{$_});
      next unless $value;
      push @where_tokens, sprintf "$token %s ?", /from$/ ? '>=' : '<=';
      push @bind_vars,    $value;
    }
  }

  if ($form->{"partsgroup_id"}) {
    $form->{"l_partsgroup"} = '1'; # show the column
    push @where_tokens, "pg.id = ?";
    push @bind_vars, $form->{"partsgroup_id"};
  }

  if ($form->{shop} ne '') {
    $form->{l_shop} = '1'; # show the column
    if ($form->{shop} eq '0' || $form->{shop} eq 'f') {
      push @where_tokens, 'NOT p.shop';
      $form->{shop} = 'f';
    } else {
      push @where_tokens, 'p.shop';
    }
  }

  foreach (@like_filters) {
    next unless $form->{$_};
    $form->{"l_$_"} = '1'; # show the column
    push @where_tokens, "$table_prefix{$_}$_ ILIKE ?";
    push @bind_vars,    like($form->{$_});
  }

  foreach (@simple_l_switches) {
    next unless $form->{"l_$_"};
    push @select_tokens, $_;
  }

  # Oder Bedingungen fuer Ware Dienstleistung Erzeugnis:
  if ($form->{l_part} || $form->{l_assembly} || $form->{l_service} || $form->{l_assortment}) {
      my @or_tokens = ();
      push @or_tokens, "p.part_type = 'service'"    if $form->{l_service};
      push @or_tokens, "p.part_type = 'assembly'"   if $form->{l_assembly};
      push @or_tokens, "p.part_type = 'part'"       if $form->{l_part};
      push @or_tokens, "p.part_type = 'assortment'" if $form->{l_assortment};
      push @where_tokens, join ' OR ', map { "($_)" } @or_tokens;
  }
  else {
      # gar keine Teile
      push @where_tokens, q|'F' = 'T'|;
  }

  if ( $form->{classification_id} > 0 ) {
    push @where_tokens, "p.classification_id = ?";
    push @bind_vars, $form->{classification_id};
  }

  for ($form->{itemstatus}) {
    push @where_tokens, 'p.id NOT IN
        (SELECT DISTINCT parts_id FROM invoice UNION
         SELECT DISTINCT parts_id FROM assembly UNION
         SELECT DISTINCT parts_id FROM orderitems)'    if /orphaned/;
    push @where_tokens, 'p.onhand = 0'                 if /orphaned/;
    push @where_tokens, 'NOT p.obsolete'               if /active/;
    push @where_tokens, '    p.obsolete',              if /obsolete/;
    push @where_tokens, 'p.onhand > 0',                if /onhand/;
    push @where_tokens, 'p.onhand < p.rop',            if /short/;
  }

  my $q_assembly_lastcost =
    qq|(SELECT SUM(a_lc.qty * p_lc.lastcost / COALESCE(pfac_lc.factor, 1))
        FROM assembly a_lc
        LEFT JOIN parts p_lc            ON (a_lc.parts_id        = p_lc.id)
        LEFT JOIN price_factors pfac_lc ON (p_lc.price_factor_id = pfac_lc.id)
        WHERE (a_lc.id = p.id)) AS lastcost|;
  $table_prefix{$q_assembly_lastcost} = ' ';

  # special case makemodel search
  # all_parts is based upon the assumption that every parameter is named like the column it represents
  # unfortunately make would have to match vendor.name which is already taken for vendor.name in bsooqr mode.
  # fortunately makemodel doesn't need to be displayed later, so adding a special clause to where_token is sufficient.
  if ($form->{make}) {
    push @where_tokens, 'mv.name ILIKE ?';
    push @bind_vars, like($form->{make});
  }
  if ($form->{model}) {
    push @where_tokens, 'mm.model ILIKE ?';
    push @bind_vars, like($form->{model});
  }

  # special case: sorting by partnumber
  # since partnumbers are expected to be prefixed integers, a special sorting is implemented sorting first lexically by prefix and then by suffix.
  # and yes, that expression is designed to hold that array of regexes only once, so the map is kinda messy, sorry about that.
  # ToDO: implement proper functional sorting
  # Nette Idee von Sven, gibt aber Probleme wenn die Artikelnummern groesser als 32bit sind. Korrekt waere es, dass Sort-Natural-Modul zu nehmen
  # Ich lass das mal hier drin, damit die Idee erhalten bleibt jb 28.5.2009 bug 1018
  #$form->{sort} = join ', ', map { push @select_tokens, $_; ($table_prefix{$_} = "substring(partnumber,'[") . $_ } qw|^[:digit:]]+') [:digit:]]+')::INTEGER|
  #  if $form->{sort} eq 'partnumber';

  #my $order_clause = " ORDER BY $form->{sort} $sort_order";

  my $limit_clause;
  $limit_clause = " LIMIT 100"                   if $form->{top100};
  $limit_clause = " LIMIT " . $form->{limit} * 1 if $form->{limit} * 1;

  #=== joins and complicated filters ========#

  my $bsooqr        = any { $form->{$_} } @oe_flags;
  my @bsooqr_tokens = ();

  push @select_tokens, @qsooqr_flags, 'quotation', 'cv', 'ioi.id', 'ioi.ioi'  if $bsooqr;
  push @select_tokens, @deliverydate_flags                                    if $bsooqr && $form->{l_deliverydate};
  push @select_tokens, $q_assembly_lastcost                                   if $form->{l_assembly} && $form->{l_lastcost};
  push @bsooqr_tokens, q|module = 'ir' AND NOT ioi.assemblyitem|              if $form->{bought};
  push @bsooqr_tokens, q|module = 'is' AND NOT ioi.assemblyitem|              if $form->{sold};
  push @bsooqr_tokens, q|module = 'oe' AND NOT quotation AND cv = 'customer'| if $form->{ordered};
  push @bsooqr_tokens, q|module = 'oe' AND NOT quotation AND cv = 'vendor'|   if $form->{onorder};
  push @bsooqr_tokens, q|module = 'oe' AND     quotation AND cv = 'customer'| if $form->{quoted};
  push @bsooqr_tokens, q|module = 'oe' AND     quotation AND cv = 'vendor'|   if $form->{rfq};
  push @where_tokens, join ' OR ', map { "($_)" } @bsooqr_tokens              if $bsooqr;

  $joins_needed{partsgroup}  = 1;
  $joins_needed{pfac}        = 1;
  $joins_needed{project}     = 1 if grep { $form->{$_} || $form->{"l_$_"} } @project_filters;
  $joins_needed{makemodel}   = 1 if grep { $form->{$_} || $form->{"l_$_"} } @makemodel_filters;
  $joins_needed{mv}          = 1 if $joins_needed{makemodel};
  $joins_needed{cv}          = 1 if $bsooqr;
  $joins_needed{apoe}        = 1 if $joins_needed{project} || $joins_needed{cv}   || grep { $form->{$_} || $form->{"l_$_"} } @apoe_filters;
  $joins_needed{invoice_oi}  = 1 if $joins_needed{project} || $joins_needed{apoe} || grep { $form->{$_} || $form->{"l_$_"} } @invoice_oi_filters;
  $joins_needed{bin}         = 1 if $form->{l_bin};
  $joins_needed{warehouse}   = 1 if $form->{l_warehouse};

  # special case for description search.
  # up in the simple filter section the description filter got interpreted as something like: WHERE description ILIKE '%$form->{description}%'
  # now we'd like to search also for the masked description entered in orderitems and invoice, so...
  # find the old entries in of @where_tokens and @bind_vars, and adjust them
  if ($joins_needed{invoice_oi}) {
    for (my ($wi, $bi) = (0)x2; $wi <= $#where_tokens; $bi++ if $where_tokens[$wi++] =~ /\?/) {
      next unless $where_tokens[$wi] =~ /\bdescription ILIKE/;
      splice @where_tokens, $wi, 1, 'p.description ILIKE ? OR ioi.description ILIKE ?';
      splice @bind_vars,    $bi, 0, $bind_vars[$bi];
      last;
    }
  }

  # now the master trick: soldtotal.
  if ($form->{l_soldtotal}) {
    push @where_tokens, 'NOT ioi.qty = 0';
    push @group_tokens, @select_tokens;
     map { s/.*\sAS\s+//si } @group_tokens;
    push @select_tokens, 'SUM(ioi.qty)';
  }

  #============= build query ================#

  my $token_builder = $make_token_builder->(\%joins_needed);

  my @sort_cols    = (@simple_filters, qw(id priceupdate onhand invnumber ordnumber quonumber name serialnumber soldtotal deliverydate insertdate shop));
     $form->{sort} = 'id' unless grep { $form->{"l_$_"} } grep { $form->{sort} eq $_ } @sort_cols; # sort by id if unknown or invisible column
  my $sort_order   = ($form->{revers} ? ' DESC' : ' ASC');
  my $order_clause = " ORDER BY " . $token_builder->($form->{sort}) . ($form->{revers} ? ' DESC' : ' ASC');

  my $select_clause = join ', ',    map { $token_builder->($_, 1) } @select_tokens;
  my $join_clause   = join ' ',     @joins{ grep $joins_needed{$_}, @join_order };
  my $where_clause  = join ' AND ', map { "($_)" } @where_tokens;
  my $group_clause  = @group_tokens ? ' GROUP BY ' . join ', ',    map { $token_builder->($_) } @group_tokens : '';

  # key of %no_simple_l_switch is the logical l_switch.
  # the assigned value is the 'not so simple
  # select token'
  my $no_simple_select_clause;
  foreach my $no_simple_l_switch (keys %no_simple_l_switches) {
    next unless $form->{"l_${no_simple_l_switch}"};
    $no_simple_select_clause .= ', '. $no_simple_l_switches{$no_simple_l_switch};
  }
  $select_clause .= $no_simple_select_clause;

  my %oe_flag_to_cvar = (
    bought   => 'invoice',
    sold     => 'invoice',
    onorder  => 'orderitems',
    ordered  => 'orderitems',
    rfq      => 'orderitems',
    quoted   => 'orderitems',
  );

  my ($cvar_where, @cvar_values) = CVar->build_filter_query(
    module         => 'IC',
    trans_id_field => $bsooqr ? 'ioi.id': 'p.id',
    filter         => $form,
    sub_module     => $bsooqr ? [ uniq grep { $oe_flag_to_cvar{$form->{$_}} } @oe_flags ] : undef,
  );

  if ($cvar_where) {
    $where_clause .= qq| AND ($cvar_where)|;
    push @bind_vars, @cvar_values;
  }

  my $query = <<"  SQL";
    SELECT DISTINCT $select_clause
    FROM parts p
    $join_clause
    WHERE $where_clause
    $group_clause
    $order_clause
    $limit_clause
  SQL

  $form->{parts} = selectall_hashref_query($form, $dbh, $query, @bind_vars);

  map { $_->{onhand} *= 1 } @{ $form->{parts} };

  # fix qty sign in ap. those are saved negative
  if ($bsooqr && $form->{bought}) {
    for my $row (@{ $form->{parts} }) {
      $row->{qty} *= -1 if $row->{module} eq 'ir';
    }
  }

  # post processing for assembly parts lists (bom)
  # for each part get the assembly parts and add them into the partlist.
  my @assemblies;
  if ($form->{l_assembly} && $form->{bom}) {
    $query =
      qq|SELECT p.id, p.partnumber, p.description, a.qty AS onhand,
           p.unit, p.notes, p.itime::DATE as insertdate,
           p.sellprice, p.listprice, p.lastcost,
           p.rop, p.weight, p.priceupdate,
           p.image, p.drawing, p.microfiche,
           pfac.factor
         FROM parts p
         INNER JOIN assembly a ON (p.id = a.parts_id)
         $joins{pfac}
         WHERE a.id = ?|;
    my $sth = prepare_query($form, $dbh, $query);

    foreach my $item (@{ $form->{parts} }) {
      push(@assemblies, $item);
      do_statement($form, $sth, $query, conv_i($item->{id}));

      while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
        $ref->{assemblyitem} = 1;
        map { $ref->{$_} /= $ref->{factor} || 1 } qw(sellprice listprice lastcost);
        push(@assemblies, $ref);
      }
      $sth->finish;
    }

    # copy assemblies to $form->{parts}
    $form->{parts} = \@assemblies;
  }

  if ($form->{l_pricegroups} ) {
    my $query = <<SQL;
       SELECT parts_id, price, pricegroup_id
       FROM prices
       WHERE parts_id = ?
SQL

    my $sth = prepare_query($form, $dbh, $query);

    foreach my $part (@{ $form->{parts} }) {
      do_statement($form, $sth, $query, conv_i($part->{id}));

      while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
        $part->{"pricegroup_$ref->{pricegroup_id}"} = $ref->{price};
      }
      $sth->finish;
    }
  }

  $main::lxdebug->leave_sub();

  return $form->{parts};
}

# get partnumber, description, unit, sellprice and soldtotal with choice through $sortorder for Top100
sub get_parts {
  $main::lxdebug->enter_sub();

  my ($self, $myconfig, $form, $sortorder) = @_;
  my $dbh   = $form->get_standard_dbh;
  my $order = qq| p.partnumber|;
  my $where = qq|1 = 1|;
  my @values;

  if ($sortorder eq "all") {
    $where .= qq| AND (partnumber ILIKE ?) AND (description ILIKE ?)|;
    push(@values, like($form->{partnumber}), like($form->{description}));

  } elsif ($sortorder eq "partnumber") {
    $where .= qq| AND (partnumber ILIKE ?)|;
    push(@values, like($form->{partnumber}));

  } elsif ($sortorder eq "description") {
    $where .= qq| AND (description ILIKE ?)|;
    push(@values, like($form->{description}));
    $order = "description";

  }

  my $query =
    qq|SELECT id, partnumber, description, unit, sellprice,
       classification_id
       FROM parts
       WHERE $where ORDER BY $order|;

  my $sth = prepare_execute_query($form, $dbh, $query, @values);

  my $j = 0;
  while (my $ref = $sth->fetchrow_hashref("NAME_lc")) {
    if (($ref->{partnumber} eq "*") && ($ref->{description} eq "")) {
      next;
    }

    $j++;
    $form->{"type_and_classific_$j"} = type_abbreviation($ref->{part_type}).
                                       classification_abbreviation($ref->{classification_id});
    $form->{"id_$j"}          = $ref->{id};
    $form->{"partnumber_$j"}  = $ref->{partnumber};
    $form->{"description_$j"} = $ref->{description};
    $form->{"unit_$j"}        = $ref->{unit};
    $form->{"sellprice_$j"}   = $ref->{sellprice};
    $form->{"soldtotal_$j"}   = get_soldtotal($dbh, $ref->{id});
  }    #while
  $form->{rows} = $j;
  $sth->finish;

  $main::lxdebug->leave_sub();

  return $self;
}    #end get_parts()

# gets sum of sold part with part_id
sub get_soldtotal {
  $main::lxdebug->enter_sub();

  my ($dbh, $id) = @_;

  my $query = qq|SELECT sum(qty) FROM invoice WHERE parts_id = ?|;
  my ($sum) = selectrow_query($main::form, $dbh, $query, conv_i($id));
  $sum ||= 0;

  $main::lxdebug->leave_sub();

  return $sum;
}    #end get_soldtotal

sub follow_account_chain {
  $main::lxdebug->enter_sub(2);

  my ($self, $form, $dbh, $transdate, $accno_id, $accno) = @_;

  my @visited_accno_ids = ($accno_id);

  my ($query, $sth);

  $form->{ACCOUNT_CHAIN_BY_ID} ||= {
    map { $_->{id} => $_ }
      selectall_hashref_query($form, $dbh, <<SQL, $transdate) };
    SELECT c.id, c.new_chart_id, date(?) >= c.valid_from AS is_valid, cnew.accno
    FROM chart c
    LEFT JOIN chart cnew ON c.new_chart_id = cnew.id
    WHERE NOT c.new_chart_id IS NULL AND (c.new_chart_id > 0)
SQL

  while (1) {
    my $ref = $form->{ACCOUNT_CHAIN_BY_ID}->{$accno_id};
    last unless ($ref && $ref->{"is_valid"} &&
                 !grep({ $_ == $ref->{"new_chart_id"} } @visited_accno_ids));
    $accno_id = $ref->{"new_chart_id"};
    $accno = $ref->{"accno"};
    push(@visited_accno_ids, $accno_id);
  }

  $main::lxdebug->leave_sub(2);

  return ($accno_id, $accno);
}

sub retrieve_accounts {
  $main::lxdebug->enter_sub;

  my $self     = shift;
  my $myconfig = shift;
  my $form     = shift;
  my $dbh      = $form->get_standard_dbh;
  my %args     = @_;     # index => part_id

  $form->{taxzone_id} *= 1;

  return unless grep $_, values %args; # shortfuse if no part_id supplied

  # transdate madness.
  my $transdate = "";
  if ($form->{type} eq "invoice" or $form->{type} eq "credit_note") {
    # use deliverydate for sales and purchase invoice, if it exists
    # also use deliverydate for credit notes
    if (!$form->{deliverydate}) {
      $transdate = $form->{invdate};
    } else {
      $transdate = $form->{deliverydate};
    }
  } elsif ($form->{script} eq 'ir.pl') {
    # when a purchase invoice is opened from the report of purchase invoices
    # $form->{type} isn't set, but $form->{script} is, not sure why this is or
    # whether this distinction matters in some other scenario. Otherwise one
    # could probably take out this elsif and add a
    # " or $form->{script} eq 'ir.pl' "
    # to the above if-statement
    if (!$form->{deliverydate}) {
      $transdate = $form->{invdate};
    } else {
      $transdate = $form->{deliverydate};
    }
  } elsif (($form->{type} eq "credit_note") and $form->{deliverydate}) {
    # if credit_note has a deliverydate, use this instead of invdate
    # useful for credit_notes of invoices from an old period with different tax
    # if there is no deliverydate then invdate is used, old default (see next elsif)
    # Falls hier der Stichtag für Steuern anders bestimmt wird,
    # entsprechend auch bei Taxkeys.pm anpassen
    $transdate = $form->{deliverydate};
  } elsif (($form->{type} eq "credit_note") || ($form->{script} eq 'ir.pl')) {
    $transdate = $form->{invdate};
  } else {
    $transdate = $form->{transdate};
  }

  if ($transdate eq "") {
    $transdate = DateTime->today_local->to_lxoffice;
  } else {
    $transdate = $dbh->quote($transdate);
  }
  #/transdate
  my $inc_exp = $form->{"vc"} eq "customer" ? "income_accno_id" : "expense_accno_id";

  my @part_ids = grep { $_ } values %args;
  my $in       = join ',', ('?') x @part_ids;

  my %accno_by_part = map { $_->{id} => $_ }
    selectall_hashref_query($form, $dbh, <<SQL, @part_ids);
    SELECT
      p.id, p.part_type,
      bg.inventory_accno_id,
      tc.income_accno_id AS income_accno_id,
      tc.expense_accno_id AS expense_accno_id,
      c1.accno AS inventory_accno,
      c2.accno AS income_accno,
      c3.accno AS expense_accno
    FROM parts p
    LEFT JOIN buchungsgruppen bg ON p.buchungsgruppen_id = bg.id
    LEFT JOIN taxzone_charts tc on bg.id = tc.buchungsgruppen_id
    LEFT JOIN chart c1 ON bg.inventory_accno_id = c1.id
    LEFT JOIN chart c2 ON tc.income_accno_id = c2.id
    LEFT JOIN chart c3 ON tc.expense_accno_id = c3.id
    WHERE
    tc.taxzone_id = '$form->{taxzone_id}'
    and
    p.id IN ($in)
SQL

  my $query_tax = <<SQL;
    SELECT c.accno, t.taxdescription AS description, t.rate, t.taxnumber
    FROM tax t
    LEFT JOIN chart c ON c.id = t.chart_id
    WHERE t.id IN
      (SELECT tk.tax_id
       FROM taxkeys tk
       WHERE tk.chart_id = ? AND startdate <= ?
       ORDER BY startdate DESC LIMIT 1)
SQL
  my $sth_tax = prepare_query($::form, $dbh, $query_tax);

  while (my ($index => $part_id) = each %args) {
    my $ref = $accno_by_part{$part_id} or next;

    $ref->{"inventory_accno_id"} = undef unless $ref->{"part_type"} eq 'part';

    my %accounts;
    for my $type (qw(inventory income expense)) {
      next unless $ref->{"${type}_accno_id"};
      ($accounts{"${type}_accno_id"}, $accounts{"${type}_accno"}) =
        $self->follow_account_chain($form, $dbh, $transdate, $ref->{"${type}_accno_id"}, $ref->{"${type}_accno"});
    }

    $form->{"${_}_accno_$index"} = $accounts{"${_}_accno"} for qw(inventory income expense);

    $sth_tax->execute($accounts{$inc_exp}, quote_db_date($transdate)) || $::form->dberror($query_tax);
    $ref = $sth_tax->fetchrow_hashref or next;

    $form->{"taxaccounts_$index"} = $ref->{"accno"};
    $form->{"taxaccounts"} .= "$ref->{accno} "if $form->{"taxaccounts"} !~ /$ref->{accno}/;

    $form->{"$ref->{accno}_${_}"} = $ref->{$_} for qw(rate description taxnumber);
  }

  $sth_tax->finish;

  $::lxdebug->leave_sub;
}

sub get_basic_part_info {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  Common::check_params(\%params, qw(id));

  my @ids      = 'ARRAY' eq ref $params{id} ? @{ $params{id} } : ($params{id});

  if (!scalar @ids) {
    $main::lxdebug->leave_sub();
    return ();
  }

  my $myconfig = \%main::myconfig;
  my $form     = $main::form;

  my $dbh      = $form->get_standard_dbh($myconfig);

  my $query    = qq|SELECT * FROM parts WHERE id IN (| . join(', ', ('?') x scalar(@ids)) . qq|)|;

  my $info     = selectall_hashref_query($form, $dbh, $query, map { conv_i($_) } @ids);

  if ('' eq ref $params{id}) {
    $info = $info->[0] || { };

    $main::lxdebug->leave_sub();
    return $info;
  }

  my %info_map = map { $_->{id} => $_ } @{ $info };

  $main::lxdebug->leave_sub();

  return %info_map;
}

sub prepare_parts_for_printing {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $myconfig = $params{myconfig} || \%main::myconfig;
  my $form     = $params{form}     || $main::form;

  my $dbh      = $params{dbh} || $form->get_standard_dbh($myconfig);

  my $prefix   = $params{prefix} || 'id_';
  my $rowcount = defined $params{rowcount} ? $params{rowcount} : $form->{rowcount};

  my @part_ids = keys %{ { map { $_ => 1 } grep { $_ } map { $form->{"${prefix}${_}"} } (1 .. $rowcount) } };

  if (!@part_ids) {
    $main::lxdebug->leave_sub();
    return;
  }

  my $placeholders = join ', ', ('?') x scalar(@part_ids);
  my $query        = qq|SELECT mm.parts_id, mm.model, mm.lastcost, v.name AS make
                        FROM makemodel mm
                        LEFT JOIN vendor v ON (mm.make = v.id)
                        WHERE mm.parts_id IN ($placeholders)|;

  my %makemodel    = ();

  my $sth          = prepare_execute_query($form, $dbh, $query, @part_ids);

  while (my $ref = $sth->fetchrow_hashref()) {
    $makemodel{$ref->{parts_id}} ||= [];
    push @{ $makemodel{$ref->{parts_id}} }, $ref;
  }

  $sth->finish();

  my @columns = qw(ean image microfiche drawing);

  $query      = qq|SELECT id, | . join(', ', @columns) . qq|
                   FROM parts
                   WHERE id IN ($placeholders)|;

  my %data    = selectall_as_map($form, $dbh, $query, 'id', \@columns, @part_ids);

  my %template_arrays;
  map { $template_arrays{$_} = [] } (qw(make model), @columns);

  foreach my $i (1 .. $rowcount) {
    my $id = $form->{"${prefix}${i}"};

    next if (!$id);

    foreach (@columns) {
      push @{ $template_arrays{$_} }, $data{$id}->{$_};
    }

    push @{ $template_arrays{make} },  [];
    push @{ $template_arrays{model} }, [];

    next if (!$makemodel{$id});

    foreach my $ref (@{ $makemodel{$id} }) {
      map { push @{ $template_arrays{$_}->[-1] }, $ref->{$_} } qw(make model);
    }
  }

  my $parts = SL::DB::Manager::Part->get_all(query => [ id => \@part_ids ]);
  my %parts_by_id = map { $_->id => $_ } @$parts;

  for my $i (1..$rowcount) {
    my $id = $form->{"${prefix}${i}"};
    next unless $id;
    my $prt = $parts_by_id{$id};
    my $type_abbr = type_abbreviation($prt->part_type);
    push @{ $template_arrays{part_type}         }, $prt->part_type;
    push @{ $template_arrays{part_abbreviation} }, $type_abbr;
    push @{ $template_arrays{type_and_classific}}, $type_abbr . classification_abbreviation($prt->classification_id);
    push @{ $template_arrays{separate}  }, separate_abbreviation($prt->classification_id);
  }

  $main::lxdebug->leave_sub();
  return %template_arrays;
}

sub normalize_text_blocks {
  $main::lxdebug->enter_sub();

  my $self     = shift;
  my %params   = @_;

  my $form     = $params{form}     || $main::form;

  # check if feature is enabled (select normalize_part_descriptions from defaults)
  return unless ($::instance_conf->get_normalize_part_descriptions);

  foreach (qw(description notes)) {
    $form->{$_} =~ s/\s+$//s;
    $form->{$_} =~ s/^\s+//s;
    $form->{$_} =~ s/ {2,}/ /g;
  }
   $main::lxdebug->leave_sub();
}


1;
