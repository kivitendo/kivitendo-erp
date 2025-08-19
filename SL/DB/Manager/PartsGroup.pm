package SL::DB::Manager::PartsGroup;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::PartsGroup' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'sortkey', 1 ],
           columns => { SIMPLE => 'ALL' });
}

sub get_hierarchy {
  my ($class, %params) = @_;

  my @list;
  my %not_obsolete = ($params{not_obsolete}) ? ( or => [ obsolete => 0, obsolete => undef ] ) : ();
  foreach my $root_pg ( @{ SL::DB::Manager::PartsGroup->get_all( where => [ parent_id => undef, %not_obsolete  ],
                                                                 sort_by => ('sortkey'),
                                                               ) } ) {
    $root_pg->{partscount} = $root_pg->parts_count;
    $root_pg->{level} = 0;
    push(@list, $root_pg);
    next unless scalar @{ $root_pg->children };
    my $iterator = $root_pg->partsgroup_iterator_dfs;
    while ( my $pg = $iterator->() ) {
      push(@list, $pg);
      $pg->{level} = $pg->get_level;
      $pg->{partscount} = $pg->parts_count // 0; # probably better to call this separately. Also it doesn't need to be calculated each time for dropdown
    };
  };
  @list = grep { !$_->obsolete } @list if $params{not_obsolete};
  return \@list;
}

1;
