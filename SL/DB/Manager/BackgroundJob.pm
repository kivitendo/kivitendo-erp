package SL::DB::Manager::BackgroundJob;

use strict;

use SL::DB::Helpers::Manager;
use base qw(SL::DB::Helpers::Manager);

sub object_class { 'SL::DB::BackgroundJob' }

__PACKAGE__->make_manager_methods;

sub cleanup {
  my $class = shift;
  $class->delete_all(where => [ and => [ type => 'once', last_run_at => { lt => DateTime->now_local->subtract(days => '1') } ] ]);
}

sub get_all_need_to_run {
  my $class = shift;
  return $class->get_all(where => [ and => [ active => 1, next_run_at => { le => DateTime->now_local } ] ]);
}

1;
