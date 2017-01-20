package SL::DB::Manager::RecordTemplate;

use strict;

use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::RecordTemplate' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return (
    default => [ 'template_name', 1 ],
    columns => {
      SIMPLE        => 'ALL',
      template_name => 'lower(template_name)',
    },
  );
}

1;
