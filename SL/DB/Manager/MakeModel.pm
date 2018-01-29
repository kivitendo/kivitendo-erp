package SL::DB::Manager::MakeModel;

use strict;

use SL::DB::Helper::Manager;
use SL::DB::Helper::Sorted;
use SL::DB::Helper::Paginated;
use SL::DB::Helper::Filtered;
use base qw(SL::DB::Helper::Manager);

use Carp;
use SL::DBUtils;
use SL::MoreCommon qw(listify);

sub object_class { 'SL::DB::MakeModel' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  (
    default  => [ 'sortorder', 1 ],
    columns  => {
      SIMPLE => 'ALL',
    },
    nulls    => {},
  );
}

1;
__END__
