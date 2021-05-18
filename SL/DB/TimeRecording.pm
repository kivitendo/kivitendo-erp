# This file has been auto-generated only because it didn't exist.
# Feel free to modify it at will; it will not be overwritten automatically.

package SL::DB::TimeRecording;

use strict;

use SL::Locale::String qw(t8);

use SL::DB::Helper::AttrDuration;
use SL::DB::Helper::AttrHTML;

use SL::DB::MetaSetup::TimeRecording;
use SL::DB::Manager::TimeRecording;

__PACKAGE__->meta->initialize;

__PACKAGE__->attr_duration_minutes(qw(duration));

__PACKAGE__->attr_html('description');

__PACKAGE__->before_save('_before_save_check_valid');

sub _before_save_check_valid {
  my ($self) = @_;

  my @errors = $self->validate;
  return (scalar @errors == 0);
}

sub validate {
  my ($self) = @_;

  my @errors;

  push @errors, t8('Customer must not be empty.')                              if !$self->customer_id;
  push @errors, t8('Staff member must not be empty.')                          if !$self->staff_member_id;
  push @errors, t8('Employee must not be empty.')                              if !$self->employee_id;
  push @errors, t8('Description must not be empty.')                           if !$self->description;
  push @errors, t8('Start time must be earlier than end time.')                if $self->is_time_in_wrong_order;
  push @errors, t8('Assigned order must be a sales order.')                    if $self->order_id && 'sales_order' ne $self->order->type;
  push @errors, t8('Customer of assigned order must match customer.')          if $self->order_id && $self->order->customer_id != $self->customer_id;
  push @errors, t8('Customer of assigned project must match customer.')        if $self->project_id && $self->project->customer_id && $self->project->customer_id != $self->customer_id;
  push @errors, t8('Project of assigned order must match assigned project.')
    if $self->project_id && $self->order_id && $self->order->globalproject_id && $self->project_id != $self->order->globalproject_id;

  my $conflict = $self->is_time_overlapping;
  push @errors, t8('Entry overlaps with "#1".', $conflict->displayable_times)  if $conflict;

  return @errors;
}

sub is_time_overlapping {
  my ($self) = @_;

  # Do not allow overlapping time periods.
  # Start time can be equal to another end time
  # (an end time can be equal to another start time)

  # We cannot check if no staff member is given.
  return if !$self->staff_member_id;

  # If no start time and no end time are given, there is no overlapping.
  return if !($self->start_time || $self->end_time);

  my $conflicting;

  # Start time or end time can be undefined.
  if (!$self->start_time) {
    $conflicting = SL::DB::Manager::TimeRecording->get_all(where  => [ and => [ '!id'           => $self->id,
                                                                                staff_member_id => $self->staff_member_id,
                                                                                start_time      => {lt => $self->end_time},
                                                                                end_time        => {ge => $self->end_time} ] ],
                                                           sort_by => 'start_time DESC',
                                                           limit   => 1);
  } elsif (!$self->end_time) {
    $conflicting = SL::DB::Manager::TimeRecording->get_all(where  => [ and => [ '!id'           => $self->id,
                                                                                staff_member_id => $self->staff_member_id,
                                                                                or              => [ and => [start_time => {le => $self->start_time},
                                                                                                             end_time   => {gt => $self->start_time} ],
                                                                                                     start_time => $self->start_time,
                                                                                ],
                                                                       ],
                                                           ],
                                                           sort_by => 'start_time DESC',
                                                           limit   => 1);
  } else {
    $conflicting = SL::DB::Manager::TimeRecording->get_all(where  => [ and => [ '!id'           => $self->id,
                                                                                staff_member_id => $self->staff_member_id,
                                                                                or              => [ and => [ start_time => {lt => $self->end_time},
                                                                                                              end_time   => {gt => $self->start_time} ] ,
                                                                                                     or  => [ start_time => $self->start_time,
                                                                                                              end_time   => $self->end_time, ],
                                                                                ]
                                                                       ]
                                                           ],
                                                           sort_by => 'start_time DESC',
                                                           limit   => 1);
  }

  return $conflicting->[0] if @$conflicting;
  return;
}

sub is_time_in_wrong_order {
  my ($self) = @_;

  if ($self->start_time && $self->end_time
      && $self->start_time >= $self->end_time) {
    return 1;
  }

  return;
}

sub is_duration_used {
  return !$_[0]->start_time;
}

sub displayable_times {
  my ($self) = @_;

  my $text;

  if ($self->is_duration_used) {
    $text = $self->date_as_date . ': ' . ($self->duration_as_duration_string || '--:--');

  } else {
    # placeholder
    my $ph =  $::locale->format_date_object(DateTime->new(year => 1111, month => 11, day => 11, hour => 11, minute => 11), precision => 'minute');
    $ph    =~ s{1}{-}g;
    $text  =  ($self->start_time_as_timestamp||$ph) . ' - ' . ($self->end_time_as_timestamp||$ph);
  }

  return $text;
}

1;
