package SL::BackgroundJob::ConvertTimeRecordings;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::DeliveryOrder;
use SL::DB::Part;
use SL::DB::Project;
use SL::DB::TimeRecording;
use SL::Helper::ShippedQty;
use SL::Locale::String qw(t8);

use DateTime;
use List::Util qw(any);

sub create_job {
  $_[0]->create_standard_job('7 3 1 * *'); # every first day of month at 03:07
}
use Rose::Object::MakeMethods::Generic (
 'scalar'                => [ qw(params) ],
);

#
# If job does not throw an error,
# success in background_job_histories is 'success'.
# It is 'failure' otherwise.
#
# Return value goes to result in background_job_histories.
#
sub run {
  my ($self, $db_obj) = @_;

  $self->initialize_params($db_obj->data_as_hash) if $db_obj;

  $self->{$_} = [] for qw(job_errors);

  my %customer_where;
  %customer_where = ('customer_id' => $self->params->{customer_ids}) if scalar @{ $self->params->{customer_ids} };

  my $time_recordings = SL::DB::Manager::TimeRecording->get_all(where => [date        => { ge_lt => [ $self->params->{from_date}, $self->params->{to_date} ]},
                                                                          or          => [booked => 0, booked => undef],
                                                                          '!duration' => 0,
                                                                          '!duration' => undef,
                                                                          %customer_where]);

  return t8('No time recordings to convert') if scalar @$time_recordings == 0;

  my @donumbers;

  if ($self->params->{link_order}) {
    my %time_recordings_by_order_id;
    my %orders_by_order_id;
    foreach my $tr (@$time_recordings) {
      my $order = $self->get_order_for_time_recording($tr);
      next if !$order;
      push @{ $time_recordings_by_order_id{$order->id} }, $tr;
      $orders_by_order_id{$order->id} ||= $order;
    }
    @donumbers = $self->convert_with_linking(\%time_recordings_by_order_id, \%orders_by_order_id);

  } else {
    @donumbers = $self->convert_without_linking($time_recordings);
  }

  my $msg  = t8('Number of delivery orders created:');
  $msg    .= ' ';
  $msg    .= scalar @donumbers;
  $msg    .= ' (';
  $msg    .= join ', ', @donumbers;
  $msg    .= ').';
  # die if errors exists
  if (@{ $self->{job_errors} }) {
    $msg  .= ' ' . t8('The following errors occurred:');
    $msg  .= ' ';
    $msg  .= join "\n", @{ $self->{job_errors} };
    die $msg . "\n";
  }
  return $msg;
}

# helper
sub initialize_params {
  my ($self, $data) = @_;

  # valid parameters with default values
  my %valid_params = (
    from_date       => DateTime->new( day => 1,    month => DateTime->today_local->month, year => DateTime->today_local->year)->subtract(months => 1)->to_kivitendo,
    to_date         => DateTime->last_day_of_month(month => DateTime->today_local->month, year => DateTime->today_local->year)->subtract(months => 1)->to_kivitendo,
    customernumbers => [],
    part_id         => undef,
    project_id      => undef,
    rounding        => 1,
    link_order      => 0,
  );


  # check user input param names
  foreach my $param (keys %$data) {
    die "Not a valid parameter: $param" unless exists $valid_params{$param};
  }

  # set defaults
  $self->params(
    { map { ($_ => $data->{$_} // $valid_params{$_}) } keys %valid_params }
  );


  # convert date from string to object
  my $from_date;
  my $to_date;
  $from_date = DateTime->from_kivitendo($self->params->{from_date});
  $to_date   = DateTime->from_kivitendo($self->params->{to_date});
  # DateTime->from_kivitendo returns undef if the string cannot be parsed. Therefore test the result.
  die 'Cannot convert date from string "' . $self->params->{from_date} . '"' if !$from_date;
  die 'Cannot convert date to string "'   . $self->params->{to_date}   . '"' if !$to_date;

  $to_date->add(days => 1); # to get all from the to_date, because of the time part (15.12.2020 23.59 > 15.12.2020)

  $self->params->{from_date} = $from_date;
  $self->params->{to_date}   = $to_date;


  # check if customernumbers are valid
  die 'Customer numbers must be given in an array' if 'ARRAY' ne ref $self->params->{customernumbers};

  my $customers = [];
  if (scalar @{ $self->params->{customernumbers} }) {
    $customers = SL::DB::Manager::Customer->get_all(where => [ customernumber => $self->params->{customernumbers},
                                                               or             => [obsolete => undef, obsolete => 0] ]);
  }
  die 'Not all customer numbers are valid' if scalar @$customers != scalar @{ $self->params->{customernumbers} };

  # return customer ids
  $self->params->{customer_ids} = [ map { $_->id } @$customers ];


  # check part
  if ($self->params->{part_id} && !SL::DB::Manager::Part->find_by(id => $self->params->{part_id},
                                                                  or => [obsolete => undef, obsolete => 0])) {
    die 'No valid part found by given part id';
  }


  # check project
  if ($self->params->{project_id} && !SL::DB::Manager::Project->find_by(id => $self->params->{project_id},
                                                                        active => 1, valid => 1)) {
    die 'No valid project found by given project id';
  }

  return $self->params;
}

sub convert_without_linking {
  my ($self, $time_recordings) = @_;

  my %time_recordings_by_customer_id;
  push @{ $time_recordings_by_customer_id{$_->customer_id} }, $_ for @$time_recordings;

  my %convert_params = (
    rounding        => $self->params->{rounding},
    default_part_id => $self->params->{part_id},
  );

  my @donumbers;
  foreach my $customer_id (keys %time_recordings_by_customer_id) {
    my $do;
    if (!eval {
      $do = SL::DB::DeliveryOrder->new_from_time_recordings($time_recordings_by_customer_id{$customer_id}, %convert_params);
      1;
    }) {
      $self->log_error("creating delivery order failed ($@) for time recording ids " . join ', ', map { $_->id } @{$time_recordings_by_customer_id{$customer_id}});
    }

    if ($do) {
      if (!SL::DB->client->with_transaction(sub {
        $do->save;
        $_->update_attributes(booked => 1) for @{$time_recordings_by_customer_id{$customer_id}};
        1;
      })) {
        $self->log_error('saving delivery order failed for time recording ids ' . join ', ', map { $_->id } @{$time_recordings_by_customer_id{$customer_id}});
      } else {
        push @donumbers, $do->donumber;
      }
    }
  }

  return @donumbers;
}

sub convert_with_linking {
  my ($self, $time_recordings_by_order_id, $orders_by_order_id) = @_;

  my %convert_params = (
    rounding        => $self->params->{rounding},
    default_part_id => $self->params->{part_id},
  );

  my @donumbers;
  foreach my $related_order_id (keys %$time_recordings_by_order_id) {
    my $related_order = $orders_by_order_id->{$related_order_id};
    my $do;
    if (!eval {
      $do = SL::DB::DeliveryOrder->new_from_time_recordings($time_recordings_by_order_id->{$related_order_id}, related_order => $related_order, %convert_params);
      1;
    }) {
      $self->log_error("creating delivery order failed ($@) for time recording ids " . join ', ', map { $_->id } @{$time_recordings_by_order_id->{$related_order_id}});
    }

    if ($do) {
      if (!SL::DB->client->with_transaction(sub {
        $do->save;
        $_->update_attributes(booked => 1) for @{$time_recordings_by_order_id->{$related_order_id}};

        $related_order->link_to_record($do);

        # TODO extend link_to_record for items, otherwise long-term no d.r.y.
        foreach my $item (@{ $do->items }) {
          foreach (qw(orderitems)) {
            if ($item->{"converted_from_${_}_id"}) {
              die unless $item->{id};
              RecordLinks->create_links('mode'       => 'ids',
                                        'from_table' => $_,
                                        'from_ids'   => $item->{"converted_from_${_}_id"},
                                        'to_table'   => 'delivery_order_items',
                                        'to_id'      => $item->{id},
              ) || die;
              delete $item->{"converted_from_${_}_id"};
            }
          }
        }

        # update delivered and item's ship for related order
        my $helper = SL::Helper::ShippedQty->new->calculate($related_order)->write_to_objects;
        $related_order->delivered($related_order->{delivered});
        $_->ship($_->{shipped_qty}) for @{$related_order->items};
        $related_order->save(cascade => 1);

        1;
      })) {
        $self->log_error('saving delivery order failed for time recording ids ' . join ', ', map { $_->id } @{$time_recordings_by_order_id->{$related_order_id}});

      } else {
        push @donumbers, $do->donumber;
      }
    }
  }

  return @donumbers;
}

sub get_order_for_time_recording {
  my ($self, $tr) = @_;

  my $orders;

  if (!$tr->order_id) {
    # check project
    my $project_id;
    #$project_id   = $self->override_project_id;
    $project_id   = $self->params->{project_id};
    $project_id ||= $tr->project_id;
    #$project_id ||= $self->default_project_id;

    if (!$project_id) {
      $self->log_error('searching related order failed for time recording id ' . $tr->id . ' : no project id');
      return;
    }

    my $project = SL::DB::Project->load_cached($project_id);

    if (!$project) {
      $self->log_error('searching related order failed for time recording id ' . $tr->id . ' : project not found');
      return;
    }
    if (!$project->active || !$project->valid) {
      $self->log_error('searching related order failed for time recording id ' . $tr->id . ' : project not active or not valid');
      return;
    }
    if ($project->customer_id && $project->customer_id != $tr->customer_id) {
      $self->log_error('searching related order failed for time recording id ' . $tr->id . ' : project customer does not match customer of time recording');
      return;
    }

    $orders = SL::DB::Manager::Order->get_all(where        => [customer_id      => $tr->customer_id,
                                                               or               => [quotation => undef, quotation => 0],
                                                               globalproject_id => $project_id, ],
                                              with_objects => ['orderitems']);

  } else {
    # order_id given
    my $order = SL::DB::Manager::Order->find_by(id => $tr->order_id);
    push @$orders, $order if $order;
  }

  if (!scalar @$orders) {
    $self->log_error('searching related order failed for time recording id ' . $tr->id . ' : no order found');
    return;
  }

  # check part
  my $part_id;
  #$part_id   = $self->override_part_id;
  $part_id ||= $tr->part_id;
  #$part_id ||= $self->default_part_id;
  $part_id ||= $self->params->{part_id};

  if (!$part_id) {
    $self->log_error('searching related order failed for time recording id ' . $tr->id . ' : no part id');
    return;
  }
  my $part = SL::DB::Part->load_cached($part_id);
  if (!$part->unit_obj->is_time_based) {
    $self->log_error('searching related order failed for time recording id ' . $tr->id . ' : part unit is not time based');
    return;
  }

  my @matching_orders;
  foreach my $order (@$orders) {
    if (any { $_->parts_id == $part_id } @{ $order->items_sorted }) {
      push @matching_orders, $order;
    }
  }

  if (1 != scalar @matching_orders) {
    $self->log_error('searching related order failed for time recording id ' . $tr->id . ' : no or more than one orders do match');
    return;
  }

  my $matching_order = $matching_orders[0];

  if (!$matching_order->is_sales) {
    $self->log_error('searching related order failed for time recording id ' . $tr->id . ' : found order is not a sales order');
    return;
  }

  if ($matching_order->customer_id != $tr->customer_id) {
    $self->log_error('searching related order failed for time recording id ' . $tr->id . ' : customer of order does not match customer of time recording');
    return;
  }

  if ($tr->project_id && $tr->project_id != ($matching_order->globalproject_id || 0)) {
    $self->log_error('searching related order failed for time recording id ' . $tr->id . ' : project of order does not match project of time recording');
    return;
  }

  return $matching_order;
}

sub log_error {
  my ($self, $msg) = @_;

  my $dbg = 0;

  push @{ $self->{job_errors} }, $msg;
  $::lxdebug->message(LXDebug->WARN(), 'ConvertTimeRecordings: ' . $msg) if $dbg;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::BackgroundJob::ConvertTimeRecordings - Convert time recording
entries into delivery orders

=head1 SYNOPSIS

Get all time recording entries for the given period and customer numbers
and create delivery ordes out of that (using
C<SL::DB::DeliveryOrder-E<gt>new_from_time_recordings>).

=head1 CONFIGURATION

Some data can be provided to configure this backgroung job.
If there is user data and it cannot be validated the background job
fails.

Example:

  from_date: 01.12.2020
  to_date: 15.12.2020
  customernumbers: [1,2,3]

=over 4

=item C<from_date>

The date from which on time recordings should be collected. It defaults
to the first day of the previous month.

Example (format depends on your settings):

from_date: 01.12.2020

=item C<to_date>

The date till which time recordings should be collected. It defaults
to the last day of the previous month.

Example (format depends on your settings):

to_date: 15.12.2020

=item C<customernumbers>

An array with the customer numbers for which time recordings should
be collected. If not given, time recordings for all customers are
collected.

customernumbers: [c1,22332,334343]

=item C<part_id>

The part id of a time based service which should be used to
book the times if no part is set in the time recording entry.

=item C<rounding>

If set the 0 no rounding of the times will be done otherwise
the times will be rounded up to the full quarters of an hour,
ie. 0.25h 0.5h 0.75h 1.25h ...
Defaults to rounding true (1).

=item C<link_order>

If set the job links the created delivery order with the order
given in the time recording entry. If there is no order given, then
it tries to find an order with the current customer and project
number. It tries to do as much automatic workflow processing as the
UI.
Defaults to off. If set to true (1) the job will fail if there
is no sales order which qualifies as a predecessor.
Conditions for a predeccesor:

 * Order given in time recording entry OR
 * Global project_id must match time_recording.project_id OR data.project_id
 * Customer must match customer in time recording entry
 * The sales order must have at least one or more time related services
 * The Project needs to be valid and active

The job doesn't care if the sales order is already delivered or closed.
If the sales order is overdelivered some organisational stuff needs to be done.
The sales order may also already be closed, ie the amount is fully billed, but
the services are not yet fully delivered (simple case: 'Payment in advance').

Hint: take a look or extend the job CloseProjectsBelongingToClosedSalesOrder for
further automatisation of your organisational needs.

=item C<project_id>

Use this project_id instead of the project_id in the time recordings.

=back

=head1 TODO

=over 4

=item * part and project parameters as numbers

Add parameters to give part and project not with their ids, but with their
numbers. E.g. (default_/override_)part_number,
(default_/override_)project_number.

=item * part and project parameters override and default

In the moment, the part id given as parameter is used as the default value.
This means, it will be used if there is no part in the time recvording entry.

The project id given is used as override parameter. It overrides the project
given in the time recording entry.

To solve this, there should be parameters named override_part_id,
default_part_id, override_project_id and default_project_id.


=back

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
