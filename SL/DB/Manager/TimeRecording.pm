# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::Manager::TimeRecording;

use strict;

use parent qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::TimeRecording' }

__PACKAGE__->make_manager_methods;


sub _sort_spec {
  return ( default => [ 'start_time', 1 ],
           nulls   => {
             date       => 'FIRST',
             start_time => 'FIRST',
             end_time   => 'FIRST',
           },
           columns => { SIMPLE     => 'ALL' ,
                        start_time => [ 'date', 'start_time' ],
                        end_time   => [ 'date', 'end_time' ],
                        customer   => [ 'lower(customer.name)', 'date','start_time'],
           }
  );
}


1;
