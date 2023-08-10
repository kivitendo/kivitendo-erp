package SL::Clearing;

use strict;
use warnings;

use SL::DB::Employee;
use SL::DB::Cleared;
use SL::DB::ClearedGroup;
use SL::DBUtils;

sub create_cleared_group {
  my ($acc_trans_ids) = @_;

  my @acc_trans_ids = @$acc_trans_ids;

  die "need at least 2 acc_trans entries" unless scalar @acc_trans_ids > 1;

  my $db = SL::DB->client;

  $db->with_transaction(sub {
    # check that
    # * sum of selected acc_trans amounts is 0
    # * there is more than 1 acc_trans
    # * they are all for the same chart
    # * and the chart is configured for clearing
    # * none of the transactions have been cleared yet
    #
    # to save db calls or later calculations in code, do this is all with one query

    my $query = <<SQL;
with selected_acc_trans as (
  select a.amount, a.chart_id,
         c.clearing,
         cl.cleared_group_id
    from acc_trans a
         left join chart c on (c.id = a.chart_id)
         left join cleared cl on (cl.acc_trans_id = a.acc_trans_id)
   where a.acc_trans_id = any(?)
),
sum_and_count as (
  select count(amount) as count,
         sum(amount)   as sum
    from selected_acc_trans
),
all_transactions_uncleared as (
  select case when count(*) > 0
              then false
              else true
              end as all_transactions_uncleared
    from selected_acc_trans
   where cleared_group_id is not null
),
distinct_charts as (
  select count(distinct chart_id) as number_of_distinct_charts
    from selected_acc_trans
),
all_charts_have_clearing as (
  select case when count(*) > 0
              then false
              else true
              end as all_charts_have_clearing
    from selected_acc_trans
   where clearing is false
)
select ( select sum from sum_and_count ),
       ( select count from sum_and_count ),
       ( select all_transactions_uncleared from all_transactions_uncleared ),
       ( select number_of_distinct_charts from distinct_charts ),
       ( select all_charts_have_clearing from all_charts_have_clearing )
SQL
    my ($sum, $count, $all_transactions_uncleared, $number_of_distinct_charts, $all_charts_have_clearing)
      = selectfirst_array_query($::form, $db->dbh, $query, \@acc_trans_ids);

    die "clearing error: sum isn't 0" unless $sum == 0;
    die "clearing error: need to select more than one transaction" unless $count > 1;
    die "clearing error: no acc_trans selected" unless $count > 1;
    die "clearing error: some bookings have already been cleared" unless $all_transactions_uncleared;
    die "clearing error: all bookings must be for the same chart" unless $number_of_distinct_charts == 1;
    die "clearing error: can only clear bookings for charts that are configured for clearing" unless $all_charts_have_clearing;

    my $cg = SL::DB::ClearedGroup->new(
      employee_id => SL::DB::Manager::Employee->current->id,
    )->save;

    foreach my $acc_trans_id ( @acc_trans_ids ) {
      SL::DB::Cleared->new(
        acc_trans_id     => $acc_trans_id,
        cleared_group_id => $cg->id,
      )->save;
    }
    return $cg;
  }) or do {
    die "error while saving cleared_group: " . $@;
  };
}

sub remove_cleared_group {
  my ($cleared_group_id) = @_;

  my $result = SL::DB::ClearedGroup->new(id => $cleared_group_id)->delete;
  $result ? return 1 : die "error while deleting cleared_group";
}

sub load_chart_transactions {
  my ($params) = @_;

  # possible params:
  #
  # chart_id  (necessary)
  # fromdate
  # todate
  # project_id
  # department_id
  # load_cleared

  die "missing chart_id param" unless $params->{chart_id};
  my $dbh = SL::DB->client->dbh;

  my %params = %{$params};

  my @sql_params = delete $params{"chart_id"};

  my $WHERE = '';

  # only load cleared bookings if this is explicitly desired
  if ( $params{"load_cleared"} ) {
    delete $params{"load_cleared"};
  } else {
    $WHERE .= ' and cl.cleared_group_id is null ';
  };

  if ( $params{"fromdate"} && ref($params{"fromdate"}) eq 'DateTime' ) {
    push(@sql_params, delete $params{"fromdate"});
    $WHERE .= ' and a.transdate >= ? '
  }

  if ( $params{"todate"} && ref($params{"todate"}) eq 'DateTime' ) {
    push(@sql_params, delete $params{"todate"});
    $WHERE .= ' and a.transdate <= ? '
  }

  my $PROJECT_WHERE = '';
  if ( $params{"project_id"} ) {
    $PROJECT_WHERE = ' and coalesce(a.project_id, ap.globalproject_id, ar.globalproject_id) = ? ';
    push(@sql_params, delete $params{"project_id"});
  }

  my $DEPARTMENT_WHERE = '';
  if ( $params{"department_id"} ) {
    $DEPARTMENT_WHERE = ' and coalesce(ap.department_id, ar.department_id, gl.department_id) = ? ';
    push(@sql_params, delete $params{"department_id"});
  }

  # if ( keys %params) {
  #   # hash not empty, log it
  #   $main::lxdebug->dump(0, "found illegal params in Clearing load_data", \%params);
  # }

  # limit number of transactions to be loaded, so you don't overwhelm the
  # interface if you forget to set dates
  my $LIMIT = 1500; # TODO: better way of dealing with limit.

  my $sql = <<"SQL";
select a.acc_trans_id,
       a.itime,
       a.amount, a.transdate,
       case when a.amount > 0 then a.amount      else null end as credit,
       case when a.amount < 0 then a.amount * -1 else null end as debit,
       c.accno, c.description,
       p.id as project_id, p.projectnumber, p.description as projectdescription,
       case when cl.acc_trans_id is not null then true else false end as cleared,
       cl.cleared_group_id,
       e.name as employee,
       e.id as employee_id,
       coalesce(gl.reference, ar.invnumber, ap.invnumber) as reference,
       case when gl.id is not null then 'gl'
            when ar.id is not null then 'ar'
                                   else 'ap'
            end as record_type,
       gegen_chart_accnos.accnos as gegen_chart_accnos
  from acc_trans a
       left join chart c on (c.id = a.chart_id)
       left join gl on (gl.id = a.trans_id)
       left join ar on (ar.id = a.trans_id)
       left join ap on (ap.id = a.trans_id)
       left join project p on (p.id = coalesce(a.project_id, ap.globalproject_id, ar.globalproject_id))
       left join employee e on (coalesce(gl.employee_id, ar.employee_id, ap.employee_id) = e.id)
       left join cleared cl on (cl.acc_trans_id = a.acc_trans_id)
       left join lateral (
                           select string_agg(chart.accno, ', ' ) as accnos
                             from acc_trans
                                  left join chart on (chart.id = acc_trans.chart_id)
                            where trans_id = a.trans_id and acc_trans_id != a.acc_trans_id
                              and sign(a.amount) != sign(amount)  -- ignore charts of opposite sign
                         ) gegen_chart_accnos on true
 where c.id = ?
       $WHERE
       $PROJECT_WHERE
       $DEPARTMENT_WHERE
order by a.transdate
limit $LIMIT
SQL

  selectall_hashref_query($::form, $dbh, $sql, @sql_params);
}

sub load_cleared_group_transactions_by_group_id {
  my ($cleared_group_id) = @_;

  my $dbh = SL::DB->client->dbh;

  my $sql = <<"SQL";
select a.acc_trans_id,
       a.amount, a.transdate,
       case when a.amount > 0 then a.amount      else null end as credit,
       case when a.amount < 0 then a.amount * -1 else null end as debit,
       c.accno, c.description,
       case when cl.acc_trans_id is not null then true else false end as cleared,
       cl.cleared_group_id,
       cg.itime,
       e.name as employee,
       e.id as employee_id,
       coalesce(gl.reference, ar.invnumber, ap.invnumber) as reference,
       case when gl.id is not null then 'gl'
            when ar.id is not null then 'ar'
                                   else 'ap'
            end as record_type,
       gegen_chart_accnos.accnos as gegen_chart_accnos
  from cleared cl
       left join cleared_group cg on (cg.id = cl.cleared_group_id)
       left join acc_trans a      on (cl.acc_trans_id = a.acc_trans_id)
       left join chart c          on (c.id = a.chart_id)
       left join gl               on (gl.id = a.trans_id)
       left join ar               on (ar.id = a.trans_id)
       left join ap               on (ap.id = a.trans_id)
       left join employee e       on (cg.employee_id = e.id )   -- employee is the employee who cleared it
       left join lateral (
                           select string_agg(chart.accno, ', ' ) as accnos
                             from acc_trans
                                  left join chart on (chart.id = acc_trans.chart_id)
                            where trans_id = a.trans_id and acc_trans_id != a.acc_trans_id
                              and sign(a.amount) != sign(amount)  -- ignore bookings of opposite sign
                         ) gegen_chart_accnos on true
 where cl.cleared_group_id = ?
order by a.transdate
SQL
  my $data = selectall_hashref_query($::form, $dbh, $sql, $cleared_group_id);
  return $data;
}

1;
