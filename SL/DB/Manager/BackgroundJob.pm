package SL::DB::Manager::BackgroundJob;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Paginated;
use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::BackgroundJob' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return ( default => [ 'next_run_at', 1 ],
           columns => { SIMPLE => 'ALL' } );
}

sub cleanup {
  my $class = shift;
  $class->delete_all(where => [ and => [ type => 'once', last_run_at => { lt => DateTime->now_local->subtract(days => '1') } ] ]);
}

sub get_all_need_to_run {
  my $class         = shift;

  my $now           = DateTime->now_local;
  my @interval_args = (and => [ type        => 'interval',
                                active      => 1,
                                next_run_at => { le => $now } ]);
  my @once_args     = (and => [ type        => 'once',
                                active      => 1,
                                last_run_at => undef,
                                or          => [ cron_spec   => undef,
                                                 cron_spec   => '',
                                                 next_run_at => undef,
                                                 next_run_at => { le => $now } ] ]);

  return $class->get_all(query => [ or => [ @interval_args, @once_args ] ]);
}

1;
