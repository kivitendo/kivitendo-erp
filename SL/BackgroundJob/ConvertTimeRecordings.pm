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
use Try::Tiny;

sub create_job {
  $_[0]->create_standard_job('7 3 1 * *'); # every first day of month at 03:07
}
use Rose::Object::MakeMethods::Generic (
 'scalar'                => [ qw(data) ],
 'scalar --get_set_init' => [ qw(rounding link_project) ],
);

# valid parameters -> better as class members with rose generic set/get
my %valid_params = (
              from_date => '',
              to_date   => '',
              customernumbers => '',
              part_id => '',
              rounding => 1,
              link_project => 0,
              project_id => '',
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

  $self->data($db_obj->data_as_hash) if $db_obj;

  $self->{$_} = [] for qw(job_errors);

  # check user input param names
  foreach my $param (keys %{ $self->data }) {
    die "Not a valid parameter: $param" unless exists $valid_params{$param};
  }

  # TODO check user input param values - (defaults are assigned later)
  # 1- If there are any customer numbers check if they refer to valid customers
  #    otherwise croak and do nothing
  # 2 .. n Same applies for other params if used at all (rounding -> 0|1  link_project -> 0|1)

  # from/to date from data. Defaults to begining and end of last month.
  # TODO get/set see above
  my $from_date;
  my $to_date;
  # handle errors with a catch handler
  try {
    $from_date   = DateTime->from_kivitendo($self->data->{from_date}) if $self->data->{from_date};
    $to_date     = DateTime->from_kivitendo($self->data->{to_date})   if $self->data->{to_date};
  } catch {
    die "Cannot convert date from string $self->data->{from_date} $self->data->{to_date}\n Details :\n $_"; # not $@
  };
  $from_date ||= DateTime->new( day => 1,    month => DateTime->today_local->month, year => DateTime->today_local->year)->subtract(months => 1);
  $to_date   ||= DateTime->last_day_of_month(month => DateTime->today_local->month, year => DateTime->today_local->year)->subtract(months => 1);

  $to_date->add(days => 1); # to get all from the to_date, because of the time part (15.12.2020 23.59 > 15.12.2020)

  my %customer_where;
  %customer_where = ('customer.customernumber' => $self->data->{customernumbers}) if 'ARRAY' eq ref $self->data->{customernumbers};

  my $time_recordings = SL::DB::Manager::TimeRecording->get_all(where        => [date => { ge_lt => [ $from_date, $to_date ]},
                                                                                 or   => [booked => 0, booked => undef],
                                                                                 %customer_where],
                                                                with_objects => ['customer']);

  # no time recordings at all ? -> better exit here before iterating a empty hash
  # return undef or message unless ref $time_recordings->[0] eq SL::DB::Manager::TimeRecording;

  my @donumbers;

  if ($self->data->{link_project}) {
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

# inits

sub init_rounding {
  1
}

sub init_link_project {
  0
}

# helper
sub convert_without_linking {
  my ($self, $time_recordings) = @_;

  my %time_recordings_by_customer_id;
  push @{ $time_recordings_by_customer_id{$_->customer_id} }, $_ for @$time_recordings;

  my %convert_params = map { $_ => $self->data->{$_} } qw(rounding link_project project_id);
  $convert_params{default_part_id} = $self->data->{part_id};

  my @donumbers;
  foreach my $customer_id (keys %time_recordings_by_customer_id) {
    my $do;
    if (!eval {
      $do = SL::DB::DeliveryOrder->new_from_time_recordings($time_recordings_by_customer_id{$customer_id}, %convert_params);
      1;
    }) {
      $::lxdebug->message(LXDebug->WARN(),
                          "ConvertTimeRecordings: creating delivery order failed ($@) for time recording ids " . join ', ', map { $_->id } @{$time_recordings_by_customer_id{$customer_id}});
      push @{ $self->{job_errors} }, "ConvertTimeRecordings: creating delivery order failed ($@) for time recording ids " . join ', ', map { $_->id } @{$time_recordings_by_customer_id{$customer_id}};

    }

    if ($do) {
      if (!SL::DB->client->with_transaction(sub {
        $do->save;
        $_->update_attributes(booked => 1) for @{$time_recordings_by_customer_id{$customer_id}};
        1;
      })) {
        $::lxdebug->message(LXDebug->WARN(),
                            "ConvertTimeRecordings: saving delivery order failed for time recording ids " . join ', ', map { $_->id } @{$time_recordings_by_customer_id{$customer_id}});
        push @{ $self->{job_errors} }, "ConvertTimeRecordings: saving delivery order failed for time recording ids " . join ', ', map { $_->id } @{$time_recordings_by_customer_id{$customer_id}};
      } else {
        push @donumbers, $do->donumber;
      }
    }
  }

  return @donumbers;
}

sub convert_with_linking {
  my ($self, $time_recordings_by_order_id, $orders_by_order_id) = @_;

  my %convert_params = map { $_ => $self->data->{$_} } qw(rounding link_project project_id);
  $convert_params{default_part_id} = $self->data->{part_id};

  my @donumbers;
  foreach my $related_order_id (keys %$time_recordings_by_order_id) {
    my $related_order = $orders_by_order_id->{$related_order_id};
    my $do;
    if (!eval {
      $do = SL::DB::DeliveryOrder->new_from_time_recordings($time_recordings_by_order_id->{$related_order_id}, related_order => $related_order, %convert_params);
      1;
    }) {
      $::lxdebug->message(LXDebug->WARN(),
                          "ConvertTimeRecordings: creating delivery order failed ($@) for time recording ids " . join ', ', map { $_->id } @{$time_recordings_by_order_id->{$related_order_id}});
      push @{ $self->{job_errors} }, "ConvertTimeRecordings: creating delivery order failed ($@) for time recording ids " . join ', ', map { $_->id } @{$time_recordings_by_order_id->{$related_order_id}};
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

        my $helper = SL::Helper::ShippedQty->new->calculate($related_order)->write_to_objects;
        $related_order->update_attributes(delivered => $related_order->{delivered});

        1;
      })) {
        $::lxdebug->message(LXDebug->WARN(),
                            "ConvertTimeRecordings: saving delivery order failed for time recording ids " . join ', ', map { $_->id } @{$time_recordings_by_order_id->{$related_order_id}});
        push @{ $self->{job_errors} }, "ConvertTimeRecordings: saving delivery order failed for time recording ids " . join ', ', map { $_->id } @{$time_recordings_by_order_id->{$related_order_id}};
      } else {
        push @donumbers, $do->donumber;
      }
    }
  }

  return @donumbers;
}

sub get_order_for_time_recording {
  my ($self, $tr) = @_;

  # check project
  my $project_id;
  #$project_id   = $self->overide_project_id;
  $project_id   = $self->data->{project_id};
  $project_id ||= $tr->project_id;
  #$project_id ||= $self->default_project_id;

  if (!$project_id) {
    my $err_msg = 'ConvertTimeRecordings: searching related order failed for time recording id ' . $tr->id . ' : no project id';
    $::lxdebug->message(LXDebug->WARN(), $err_msg);
    push @{ $self->{job_errors} }, $err_msg;
    return;
  }

  my $project = SL::DB::Project->load_cached($project_id);

  if (!$project) {
    my $err_msg = 'ConvertTimeRecordings: searching related order failed for time recording id ' . $tr->id . ' : project not found';
    $::lxdebug->message(LXDebug->WARN(), $err_msg);
    push @{ $self->{job_errors} }, $err_msg;
    return;
  }
  if (!$project->active || !$project->valid) {
    my $err_msg = 'ConvertTimeRecordings: searching related order failed for time recording id ' . $tr->id . ' : project not active or not valid';
    $::lxdebug->message(LXDebug->WARN(), $err_msg);
    push @{ $self->{job_errors} }, $err_msg;
    return;
  }
  if ($project->customer_id && $project->customer_id != $tr->customer_id) {
    my $err_msg = 'ConvertTimeRecordings: searching related order failed for time recording id ' . $tr->id . ' : project customer does not match customer of time recording';
    $::lxdebug->message(LXDebug->WARN(), $err_msg);
    push @{ $self->{job_errors} }, $err_msg;
    return;
  }

  # check part
  my $part_id;
  #$part_id   = $self->overide_part_id;
  $part_id ||= $tr->part_id;
  #$part_id ||= $self->default_part_id;
  $part_id ||= $self->data->{part_id};

  if (!$part_id) {
    my $err_msg = 'ConvertTimeRecordings: searching related order failed for time recording id ' . $tr->id . ' : no part id';
    $::lxdebug->message(LXDebug->WARN(), $err_msg);
    push @{ $self->{job_errors} }, $err_msg;
    return;
  }
  my $part = SL::DB::Part->load_cached($part_id);
  if (!$part->unit_obj->is_time_based) {
    my $err_msg = 'ConvertTimeRecordings: searching related order failed for time recording id ' . $tr->id . ' : part unit is not time based';
    $::lxdebug->message(LXDebug->WARN(), $err_msg);
    push @{ $self->{job_errors} }, $err_msg;
    return;
  }

  my $orders = SL::DB::Manager::Order->get_all(where => [customer_id      => $tr->customer_id,
                                                         or               => [quotation => undef, quotation => 0],
                                                         globalproject_id => $project_id, ]);
  my @matching_orders;
  foreach my $order (@$orders) {
    if (any { $_->parts_id == $part_id } @{ $order->items_sorted }) {
      push @matching_orders, $order;
    }
  }

  if (1 != scalar @matching_orders) {
    my $err_msg = 'ConvertTimeRecordings: searching related order failed for time recording id ' . $tr->id . ' : no or more than one orders do match';
    $::lxdebug->message(LXDebug->WARN(), $err_msg);
    push @{ $self->{job_errors} }, $err_msg;
    return;
  }

  return $matching_orders[0];
}

1;

# possible data
# from_date: 01.12.2020
# to_date: 15.12.2020
# customernumbers: [1,2,3]
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
returns a error messages.

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
be collected. If not given, time recordings for customers are
collected. This is the default.

customernumbers: [c1,22332,334343]

=item C<part_id>

The part id of a time based service which should be used to
book the times. If not set the clients config defaults is used.

=item C<rounding>

If set the 0 no rounding of the times will be done otherwise
the times will be rounded up to th full quarters of an hour,
ie. 0.25h 0.5h 0.75h 1.25h ...
Defaults to rounding true (1).

=item C<link_project>

If set the job tries to find a previous Order with the current
customer and project number and tries to do as much automatic
workflow processing as the UI.
Defaults to off. If set to true (1) the job will fail if there
is no Sales Orders which qualifies as a predecessor.
Conditions for a predeccesor:

 * Global project_id must match time_recording.project_id OR data.project_id
 * Customer name must match time_recording.customer_id OR data.customernumbers
 * The sales order must have at least one or more time related services
 * The Project needs to be valid and active

The job doesn't care if the Sales Order is already delivered or closed.
If the sales order is overdelivered some organisational stuff needs to be done.
The sales order may also already be closed, ie the amount is fully billed, but
the services are not yet fully delivered (simple case: 'Payment in advance').

Hint: take a look or extend the job CloseProjectsBelongingToClosedSalesOrder for
further automatisation of your organisational needs.


=item C<project_id>

Use this project_id instead of the project_id in the time recordings.

=back

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
