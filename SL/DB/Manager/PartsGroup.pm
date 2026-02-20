package SL::DB::Manager::PartsGroup;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;
use SL::DBUtils;

sub object_class { 'SL::DB::PartsGroup' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'sortkey', 1 ],
           columns => { SIMPLE => 'ALL' });
}

sub get_hierarchy {
  my ($class, %params) = @_;
  my $partsgroup_id = $params{partsgroup_id} || undef;
  my $where = $partsgroup_id ? "=?" : "IS ?";
  my $query = <<SQL;
  WITH RECURSIVE
  reclist(id,parent_id,partsgroup,description,obsolete,path,depth) AS (
    SELECT pg.id,pg.parent_id,pg.partsgroup,pg.description,pg.obsolete,ARRAY[0],0
  FROM partsgroup pg
  where pg.parent_id IS NULL
  UNION ALL
    SELECT pgc.id,pgc.parent_id,pgc.partsgroup,pgc.description,pgc.obsolete, path || pgc.parent_id, depth +1
    FROM partsgroup pgc, reclist rec
    WHERE pgc.parent_id = rec.id
  )
  SEARCH DEPTH FIRST BY "id" SET "sort_key"
  ,
  countparts AS ( SELECT partsgroup_id, count(id) as partscount FROM parts GROUP BY partsgroup_id)
  SELECT rec.id,rec.parent_id,rec.partsgroup,rec.description,rec.obsolete,rec.path,rec.depth AS level,rec.sort_key, cp.partscount FROM reclist rec 
  LEFT JOIN countparts cp ON cp.partsgroup_id = rec.id
  ORDER BY rec.id
SQL
  
  my @reclist = selectall_hashref_query($::form, SL::DB::client->dbh, $query);
  my @list;
    foreach my $rec(@reclist) {
      my $pg = SL::DB::Manager::PartsGroup->find_by( id => $rec->{id} );
      $pg->{partscount} = $rec->{partscount} || 0;
      $pg->{level} = $rec->{level};
      push(@list, $pg);
    }
    #  my %not_obsolete = ($params{not_obsolete}) ? ( or => [ obsolete => 0, obsolete => undef ] ) : ();
    #  foreach my $root_pg ( @{ SL::DB::Manager::PartsGroup->get_all( where => [ parent_id => undef, %not_obsolete  ],
    #                                                                 sort_by => ('sortkey'),
    #                                                               ) } ) {
    #    $root_pg->{partscount} = $root_pg->parts_count;
    #    $root_pg->{level} = 0;
    #    push(@list, $root_pg);
    #    next unless scalar @{ $root_pg->children };
    #    my $iterator = $root_pg->partsgroup_iterator;
    #    while ( my $pg = $iterator->() ) {
    #      push(@list, $pg);
    #      $pg->{level} = $pg->get_level;
    #      $pg->{partscount} = $pg->parts_count // 0; # probably better to call this separately. Also it doesn't need to be calculated each time for dropdown
    #    };
    #  };
  @list = grep { !$_->obsolete } @list if $params{not_obsolete};
  return \@list;
}

1;
