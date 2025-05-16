package SL::BackgroundJob::FailedBackgroundJobsReport;

use strict;
use utf8;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::BackgroundJobHistory;
use SL::Locale::String;
use SL::Mailer;

use Rose::Object::MakeMethods::Generic (
  scalar => [ qw(data start_time entries) ],
);


sub create_job {
  # Don't create this job by default
  1;
}

sub check_config {
  my ($self) = @_;

  die "No »recipients« specified" unless @{ $self->data->{recipients} || [] };
  die "No »from« specified"       unless $self->data->{from};
  die "No »subject« specified"    unless $self->data->{subject};

  return $self;
}

sub send_email {
  my ($self) = @_;

  return 1 unless @{ $self->entries };

  my $template  = Template->new({
    INTERPOLATE => 0,
    EVAL_PERL   => 0,
    ABSOLUTE    => 1,
    CACHE_SIZE  => 0,
    ENCODING    => 'utf8',
  }) || die("Could not create Template instance");

  my $file_name = $self->data->{template} || 'templates/design40_webpages/failed_background_jobs_report/email.txt';
  my $body;
  $template->process($file_name, { SELF => $self }, \$body);

  Mailer->new(
    from         => $self->data->{from},
    to           => join(', ', @{ $self->data->{recipients} }),
    subject      => $self->data->{subject},
    content_type => 'text/plain',
    charset      => 'utf-8',
    message      => $body,
  )->send;

  return $self;
}

sub load_failed_entries {
  my ($self) = @_;

  $self->start_time(DateTime->now_local->subtract(days => 1));
  $self->entries([ @{ SL::DB::Manager::BackgroundJobHistory->get_all(
    sort_by  => 'run_at ASC',
    where    => [
      status => SL::DB::BackgroundJobHistory::FAILURE(),
      run_at => { ge => $self->start_time },
    ],
  )}]);

  return $self;
}

sub run {
  my ($self, $db_obj) = @_;

  $self->data($db_obj->data_as_hash);

  $self
    ->check_config
    ->load_failed_entries
    ->send_email;

  return 1;
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::BackgroundJob::FailedBackgroundJobsReport - A background job
checking for failed jobs and reporting them via email

=head1 OVERVIEW

This background's job is to watch over other background jobs. It will
determine when it has run last and look for job history entries that
have failed between the last run and the current time.

If that search yields results then an email will be sent listing the
jobs that failed and the error messages they produced. The template
used for the email's body defaults to the file
C<templates/design40_webpages/failed_background_jobs_report/email.txt> but can
be overridden in the configuration.

This background job is not active by default. You have to add and
configure it manually.

=head1 CONFIGURATION

This background job requires configuration data stored in its data
member. This is supposed to be a YAML-encoded hash of the following
options:

=over 4

=item * C<from> – required; the sender's email address used in the
mail headers

=item * C<recipients> – required; an array of email addresses for the
recipients

=item * C<subject> – required; the email's subject

=item * C<template> – optional; a file name pointing to the template
file used for the email's body. This defaults to
C<templates/design40_webpages/failed_background_jobs_report/email.txt>.

=back

Here's an example of how this data looks like:

  ---
  from: kivitendo@meine.firma
  recipients:
    - johanna.admin@meine.firma
  subject: Fehlgeschlagene kivitendo-Jobs der letzten 24h
  template: templates/mycompany/faileed_background_jobs_email.txt

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
