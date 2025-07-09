package SL::BackgroundJob::SendFollowUpReminder;

use strict;

use parent qw(SL::BackgroundJob::Base);

use SL::DB::AuthUser;
use SL::DB::FollowUp;
use SL::Locale::String qw(t8);
use SL::Mailer;
use SL::Presenter;
use SL::Util qw(trim);

use DateTime;
use File::Slurp qw(slurp);
use List::Util qw(any);
use Try::Tiny;
use URI;

sub create_job {
  $_[0]->create_standard_job('7 6 1-5 * *'); # every workday at 06:07
}

use Rose::Object::MakeMethods::Generic (
 'scalar' => [ qw(params) ],
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

  $self->{$_} = [] for qw(job_errors);

  $self->initialize_params($db_obj->data_as_hash) if $db_obj;

  my   @follow_up_date_where = ();
  push @follow_up_date_where, (follow_up_date => { ge    => [ $self->params->{from_date} ]}) if $self->params->{from_date};
  push @follow_up_date_where, (follow_up_date => { le    => [ $self->params->{to_date}   ]}) if $self->params->{to_date};

  my $follow_ups = SL::DB::Manager::FollowUp->get_all(where        => ['done.id' => undef,
                                                                       @follow_up_date_where, ],
                                                      with_objects => ['done'],
                                                      sort_by      => ['follow_up_date']);

  # Collect follow ups for users with e-mail-address.
  my $mail_to_by_employee_id;
  foreach my $follow_up (@$follow_ups) {

    # add link
    my $base_url = $self->params->{base_url} //  $::form->_get_request_uri;
    $follow_up->{link} = URI->new_abs('fu.pl?action=edit&id=' . $follow_up->id, $base_url);

    foreach my $employee (@{ $follow_up->created_for_employees }) {
      next if $employee->deleted;

      if (!exists $mail_to_by_employee_id->{$employee->id}) {
        my $user = SL::DB::Manager::AuthUser->find_by(login => $employee->login);
        if ($user) {
          my $mail_to = trim($user->get_config_value('email'));

          next if !$mail_to;

          $mail_to_by_employee_id->{$employee->id}->{mail_to} = $mail_to;
        }
      }

      if (exists $mail_to_by_employee_id->{$employee->id}) {
        push @{ $mail_to_by_employee_id->{$employee->id}->{follow_ups} }, $follow_up;
      }
    }
  }

  foreach (keys %$mail_to_by_employee_id) {
    my ($message, $content_type) = $self->generate_message($mail_to_by_employee_id->{$_}->{follow_ups});

    my $mail              = Mailer->new;
    $mail->{from}         = $self->params->{email_from};
    $mail->{to}           = $mail_to_by_employee_id->{$_}->{mail_to};
    $mail->{bcc}          = SL::DB::Default->get->global_bcc;
    $mail->{subject}      = $self->params->{email_subject};
    $mail->{message}      = $message;
    $mail->{content_type} = $content_type;

    my $error = $mail->send;

    if ($error) {
      push @{ $self->{job_errors} }, $error;
    }
  }

  my $msg = t8('Follow ups reminder sent.');

  # die if errors exists
  if (@{ $self->{job_errors} }) {
    $msg .= t8('The following errors occurred:');
    $msg .= join "\n", @{ $self->{job_errors} };
    die $msg . "\n";
  }

  return $msg;
}

# helper
sub initialize_params {
  my ($self, $data) = @_;

  # valid parameters with default values
  my %valid_params = (
    from_date      => undef,
    to_date        => DateTime->today_local->to_kivitendo,
    email_from     => $::lx_office_conf{follow_up_reminder}->{email_from},
    email_subject  => $::lx_office_conf{follow_up_reminder}->{email_subject},
    email_template => $::lx_office_conf{follow_up_reminder}->{email_template},
    base_url       => undef,
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
  my ($from_date, $to_date);
  try {
    if ($self->params->{from_date}) {
      $from_date = DateTime->from_kivitendo($self->params->{from_date});
      # Not undef and no other type.
      die unless ref $from_date eq 'DateTime';
    }
    if ($self->params->{to_date}) {
      $to_date = DateTime->from_kivitendo($self->params->{to_date});
      # Not undef and no other type.
      die unless ref $to_date eq 'DateTime';
    }
  } catch {
    die t8("Cannot convert date.") ."\n" .
        t8("Input from string: #1", $self->params->{from_date}) . "\n" .
        t8("Input to string: #1",   $self->params->{to_date})   . "\n" .
        t8("Details: #1", $_);
  };

  $self->params->{from_date} = $from_date;
  $self->params->{to_date}   = $to_date;

  $self->params->{email_from} = trim($self->params->{email_from});
  die t8('No email sender address given.') if !$self->params->{email_from};

  return $self->params;
}

sub generate_message {
  my ($self, $follow_ups) = @_;

  # Force scripts/locales.pl to parse this template:
  # parse_html_template('fu/follow_up_reminder_mail')
  my $email_template = $self->params->{email_template};
  my $template       = 'fu/follow_up_reminder_mail';
  my $content_type   = 'text/html';
  my $render_type    = 'html';

  if ($email_template) {
    my $content;
    try {
      $content = slurp $email_template;

    } catch {
      $::lxdebug->message(LXDebug->WARN(), 'Cannot read template file. Error: ' . $_);
    };

    return $self->generate_message_simple_text($follow_ups) if !$content;

    $template     = \$content;
    $content_type = $email_template =~ m/.html$/ ? 'text/html' : 'text/plain';
    $render_type  = $email_template =~ m/.html$/ ? 'html'      : 'text';
  }

  my $output = SL::Presenter->get->render($template,
                                          {type => $render_type},
                                          follow_ups => $follow_ups);

  return ($output, $content_type);
}

sub generate_message_simple_text {
  my ($self, $follow_ups) = @_;

  my $output = t8('Unfinished follow-ups') . ":\n";
  foreach my $follow_up (@$follow_ups) {
    $output .= t8('Follow-Up Date') . ': ' . $follow_up->follow_up_date_as_date;
    $output .= ': ' . $follow_up->note->subject;
    $output .= ': (' . t8('by') . ' ' . $follow_up->created_by_employee->safe_name . ')';
    $output .= ' (' . $follow_up->{link} . ')';
    $output .= "\n";
  }

  $output .= "\n\n";

  return ($output, 'text/plain');
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::BackgroundJob::SendFollowUpReminder - Send emails to employees to
remind them of due follow ups

=head1 SYNOPSIS

Get all due follow ups. This are the ones that are not done yet and have a
follow up date until today (configurable, see below).
For each employee addreesed by this follow ups, an email is send (if the
employees email address is configured).

=head1 CONFIGURATION

In the kivitendo configuration file (C<config/kivitendo.conf>) in the section
"follow_up_reminder" some settings can be made:

=over 4

=item C<email_from>

The senders email address. This information can be overwriten by
data provided to the background job.

=item C<email_subject>

The subject of the emails. This information can be overwriten by
data provided to the background job.

=item C<email_template>

A template file used to generate the emails content. It will be given an
array of the follow ups in the template variable C<follow_ups>.
You can provide a text or a html template.
If not given, it defaults to C<fu/follow_up_reminder_mail.html> in the
webpages directory.
If given, but not found, a simple text version will be generated as
content.
This information can be overwriten by data provided to the background job.

=back

Also some data can be provided to configure this backgroung job.
If there is data provided and it cannot be validated the background job
fails.

Example:

  from_date: 01.01.2022
  to_date: 01.07.2022
  email_subject: To-Do
  base_url: https://meinkivi.firma.de/kivi/

=over 4

=item C<from_date>

The date from which on follow ups not done yet should be collected. It defaults
undef which means from the beginning on.

Example (format depends on your settings):

from_date: 01.01.2022

=item C<to_date>

The date till which follow ups not done yet should be collected. It defaults
to today.

Example (format depends on your settings):

to_date: 01.07.2022

=item C<email_from>

The senders email address. It defaults to the one given in the kivitendo
configuration file (see above). This information must be provided some
how.

Example:

email_from: bernd@kivitendo.de

=item C<email_subject>

The subject of the emails.
It defaults to the one given in the kvitendo configuration file (see above).

email_subject: To-Do

=item C<email_template>

A template file used to generate the emails content. It will be given an
array of the follow ups in the template variable C<follow_ups>. You can
provide a text or a html template.
It defaults to the one given in the kvitendo configuration file (see above).

email_template: templates/my_templates/my_reminder_template.txt

=item C<base_url>

The base URI of your kivitendo server with protocol (http://)

Example (format depends on your settings):

base_url: https://kivi.foo.bz/kivitendo-erp/


=back

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
