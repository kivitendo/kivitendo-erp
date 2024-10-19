package SL::Presenter::Filter::EmailJournal;

use parent SL::Presenter::Filter;

use strict;

use SL::Locale::String qw(t8);

use Params::Validate qw(:all);

sub get_default_filter_elements {
  my $filter = shift @_;
  my %params = validate_with(
    params => \@_,
    spec   => {
    record_types_with_info => {
      type => ARRAYREF
    },
    },
  );

  my %default_filter_elements = ( # {{{
    id => {
      'position' => 1,
      'text' => t8("ID"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.id:number',
      'input_default' => $filter->{'id:number'},
      'report_id' => 'id',
      'active' => 0,
    },
    sender => {
      'position' => 2,
      'text' => t8("Sender"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.sender.name:substr::ilike',
      'input_default' => $filter->{sender}->{'name:substr::ilike'},
      'report_id' => 'sender',
      'active' => $::auth->assert('email_employee_readall', 1),
    },
    from => {
      'position' => 3,
      'text' => t8("From"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.from:substr::ilike',
      'input_default' => $filter->{'from:substr::ilike'},
      'report_id' => 'from',
      'active' => 1,
    },
    recipients => {
      'position' => 4,
      'text' => t8("Recipients"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.recipients:substr::ilike',
      'input_default' => $filter->{'recipients:substr::ilike'},
      'report_id' => 'recipients',
      'active' => 1,
    },
    subject => {
      'position' => 5,
      'text' => t8("Subject"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.subject:substr::ilike',
      'input_default' => $filter->{'subject:substr::ilike'},
      'report_id' => 'subject',
      'active' => 1,
    },
    sent_on => {
      'position' => 6,
      'text' => t8("Sent on"),
      'input_type' => 'date_tag',
      'input_name' => 'sent_on',
      'input_default_ge' => $filter->{'sent_on' . ':date::ge'},
      'input_default_le' => $filter->{'sent_on' . ':date::le'},
      'report_id' => 'sent_on',
      'active' => 1,
    },
    attachment_names => {
      'position' => 7,
      'text' => t8("Attachments"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.attachments.name:substr::ilike',
      'input_default' => $filter->{attachments}->{'name:substr::ilike'},
      'report_id' => 'attachment_names',
      'active' => 1,
    },
    'has_unprocessed_attachments' => {
      'position' => 8,
      'text' => t8("Has unprocessed attachments"),
      'input_type' => 'yes_no_tag',
      'input_name' => 'filter.has_unprocessed_attachments:eq_ignore_empty',
      'input_default' => $filter->{'has_unprocessed_attachments:eq_ignore_empty'},
      'report_id' => 'has_unprocessed_attachments',
      'active' => 1,
    },
    unprocessed_attachment_names => {
      'position' => 9,
      'text' => t8("Unprocessed Attachments"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.unprocessed_attachment_names:substr::ilike',
      'input_default' => $filter->{'unprocessed_attachment_names:substr::ilike'},
      'report_id' => 'unprocessed_attachment_names',
      'active' => 1,
    },
    status => {
      'position' => 10,
      'text' => t8("Status"),
      'input_type' => 'select_tag',
      'input_values' => [
        [ "", "" ],
        [ "send_failed", t8("send failed") ],
        [ "sent", t8("sent") ],
        [ "imported", t8("imported") ]
      ],
      'input_name' => 'filter.status',
      'input_default' => $filter->{'status'},
      'report_id' => 'status',
      'active' => 1,
    },
    extended_status => {
      'position' => 11,
      'text' => t8("Extended status"),
      'input_type' => 'input_tag',
      'input_name' => 'filter.extended_status:substr::ilike',
      'input_default' => $filter->{'extended_status:substr::ilike'},
      'report_id' => 'extended_status',
      'active' => 1,
    },
    record_type => {
      'position' => 12,
      'text' => t8("Record Type"),
      'input_type' => 'select_tag',
      'input_values' => [
        map {[
           $_->{record_type} => $_->{text},
        ]}
        grep {!$_->{is_template}}
        {},
        {text=> t8("Catch-all"), record_type => 'catch_all'},
        @{$params{record_types_with_info}}
      ],
      'input_name' => 'filter.record_type:eq_ignore_empty',
      'input_default' => $filter->{'record_type:eq_ignore_empty'},
      'report_id' => 'record_type',
      'active' => 1,
    },
    'linked' => {
      'position' => 13,
      'text' => t8("Linked"),
      'input_type' => 'yes_no_tag',
      'input_name' => 'filter.linked_to:eq_ignore_empty',
      'input_default' => $filter->{'linked_to:eq_ignore_empty'},
      'report_id' => 'linked_to',
      'active' => 1,
    },
    'obsolete' => {
      'position' => 14,
      'text' => t8("Obsolete"),
      'input_type' => 'yes_no_tag',
      'input_name' => 'filter.obsolete:eq_ignore_empty',
      'input_default' => $filter->{'obsolete:eq_ignore_empty'},
      'report_id' => 'obsolete',
      'active' => 1,
    },
  ); # }}}
  return \%default_filter_elements;
}

sub filter {
  my $filter = shift @_;
  die "filter has to be a hash ref" if ref $filter ne 'HASH';
  my %params = validate_with(
    params => \@_,
    spec   => {
      record_types_with_info => {
        type => ARRAYREF
      },
    },
    allow_extra => 1,
  );

  my $filter_elements = get_default_filter_elements($filter,
    record_types_with_info => delete $params{record_types_with_info},
  );

  return SL::Presenter::Filter::create_filter($filter_elements, %params);
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Presenter::Filter::EmailJournal - Presenter module for a generic filter on
EmailJournal.

=head1 SYNOPSIS

  # in EmailJournal Controller
  my $filter_html = SL::Presenter::Filter::EmailJournal::filter(
    $::form->{filter},
    active_in_report => $::form->{active_in_report}
    record_types_with_info => \@record_types_with_info,
  );


=head1 FUNCTIONS

=over 4

=item C<filter $filter, %params>

Returns a rendered version (actually an instance of
L<SL::Presenter::EscapedText>) of a filter form for email journal.

C<$filter> should be the C<filter> value of the last C<$::form>. This is used to
get the previous values of the input fields.

C<%params> can include:

=over 2


= item * record_types_with_info

Is used to set the drop down for record type.

=back

Other C<%params> fields get forwarded to
C<SL::Presenter::Filter::create_filter>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Tamino Steinert E<lt>tamino.steinert@tamino.stE<gt>

=cut
