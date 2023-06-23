package SL::BackgroundJob::SelfTest;

use strict;

use parent qw(SL::BackgroundJob::Base);

use Test::Builder;
use TAP::Parser;
use TAP::Parser::Aggregator;
use Sys::Hostname;
use FindBin;

use SL::DB::AuthUser;
use SL::DB::Default;
use SL::Common;
use SL::Locale::String qw(t8);
use Carp;

use Rose::Object::MakeMethods::Generic (
  array => [
   'modules'     => {},
   'add_modules' => { interface => 'add', hash_key => 'modules' },
   'errors'      => {},
   'add_errors'  => { interface => 'add', hash_key => 'errors' },
   'full_diag'      => {},
   'add_full_diag'  => { interface => 'add', hash_key => 'full_diag' },
  ],
  scalar => [
   qw(diag tester config aggreg module_nr additional_email),
  ],
);

sub create_job {
  $_[0]->create_standard_job('20 2 * * *'); # every day at 2:20 am
}

sub setup {
  my ($self) = @_;

  $self->config($::lx_office_conf{self_test} || {});

  $self->tester(Test::Builder->new);
  $self->tester->reset; # stupid Test::Builder mplementation uses class variables
  $self->aggreg(TAP::Parser::Aggregator->new);

  $self->modules(split /\s+/, $self->config->{modules});
  $self->modules($self->{options}->{modules}) if $self->{options}->{modules};
}

sub run {
  my $self   = shift;
  my $db_obj = shift;

  # get custom options (module list || alternate email)
  $self->{options} = $db_obj->data_as_hash;
  $self->setup;

  return 1 unless $self->modules;

  # set additional mail
  $self->additional_email($self->{options}->{email}) if $self->{options}->{email} =~ m/(\S+)@(\S+)$/;

  foreach my $module ($self->modules) {
    $self->run_module($module);
  }

  $self->log(
    sprintf "SelfTest status: %s, passed: %s, failed: %s, unexpectedly succeeded: %s",
             $self->aggreg->get_status,
             $self->aggreg->passed,
             $self->aggreg->failed,
             $self->aggreg->todo_passed,
  );
  # if (!$self->aggreg->all_passed || $self->config->{send_email_on_success}) {
  # all_passed is not set or calculated (anymore). it is safe to check only for probs or errors
  if ($self->aggreg->failed || $self->config->{send_email_on_success}) {
    $self->_send_email;
  }

  croak t8("Unsuccessfully executed:" . join ("\n", $self->errors)) if $self->errors;
  return 1;
}

sub run_module {
  my ($self, $module) = @_;

  # TAP usually prints out to STDOUT and STDERR, capture those for TAP::Parser
  my $output;

  $self->tester->output        (\$output);
  $self->tester->failure_output(\$output);
  $self->tester->todo_output   (\$output);

  # sanitize module name;
  # this allows unicode package names, which are known to be buggy in 5.10, you should avoid them
  $module =~ s/[^\w:]//g;
  $module = "SL::BackgroundJob::SelfTest::$module";

  # increase module nr
  $self->module_nr(($self->module_nr || 0) + 1);

  # try to load module;
  (my $file = $module) =~ s|::|/|g;
  eval {
    require $file . '.pm';
    1
  } or $self->add_errors($::locale->text('Could not load class #1 (#2): "#3"', $module, $file, $@)) && return;

  eval {
    $self->tester->subtest($module => sub {
      $module->new->run;
    });
  1
  } or $self->add_errors($::locale->text('Could not load class #1, #2', $module, $@)) && return;

  $self->add_full_diag($output);
  $self->{diag_per_module}{$self->module_nr . ': ' . $module} = $output;

  my $parser = TAP::Parser->new({ tap => $output});
  $parser->run;

  $self->aggreg->add($module => $parser);
}

sub _email_user {
  $_[0]{email_user} ||= SL::DB::Manager::AuthUser->find_by(login => $_[0]->config->{send_email_to});
}

sub _send_email {
  my ($self) = @_;

  return if !$self->config || !$self->config->{send_email_to};

  my $user  = $self->_email_user;
  my $email = $self->{options}->{mail_to} ? $self->{options}->{mail_to}
            : $user                       ? $user->get_config_value('email')
            : undef;
  return unless $email;

  $email .= $self->additional_email ? ',' . $self->additional_email : '';

  my ($output, $content_type) = $self->_prepare_report;

  my $mail              = Mailer->new;
  $mail->{from}         = $self->config->{email_from};
  $mail->{to}           = $email;
  $mail->{subject}      = $self->config->{email_subject};
  $mail->{content_type} = $content_type;
  $mail->{message}      = $$output;

  my $err = $mail->send;
  $self->add_errors($::locale->text('Mailer error #1', $err)) if $err;

}

sub _prepare_report {
  my ($self) = @_;

  my $template = Template->new({ 'INTERPOLATE' => 0,
                                 'EVAL_PERL'   => 0,
                                 'ABSOLUTE'    => 1,
                                 'CACHE_SIZE'  => 0,
                               });

  return unless $template;
  my $email_template = $self->config->{email_template};
  my $filename       = $email_template || ( (SL::DB::Default->get->templates || "templates/mails") . "/self_test/status_mail.txt" );
  my $content_type   = $filename =~ m/.html$/ ? 'text/html' : 'text/plain';


  my %params = (
    SELF     => $self,
    host     => hostname,
    database => $::auth->client->{dbname},
    client   => $::auth->client->{name},
    path     => $FindBin::Bin,
    errors   => $self->errors,
  );

  my $output;
  $template->process($filename, \%params, \$output) || die $template->error;

  return (\$output, $content_type);
}

sub log {
  my $self = shift;
  $::lxdebug->message(0, "[" . __PACKAGE__ . "] @_") if $self->config->{log_to_file};
}


1;

__END__

=head1 NAME

SL::BackgroundJob::SelfTest - pluggable self testing

=head1 SYNOPSIS

  use SL::BackgroundJob::SelfTest;
  SL::BackgroundJob::SelfTest->new->run;;

=cut
