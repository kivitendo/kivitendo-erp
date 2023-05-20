package SL::BackgroundJob::CheckBelowMinimumStock;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use SL::Mailer;
use SL::DB::Part;
use SL::Presenter::Part qw(part);
use SL::Presenter::Tag qw(html_tag link_tag);
use SL::Presenter::EscapedText qw(escape);
use SL::DBUtils qw(selectall_hashref_query);
use SL::Locale::String qw(t8);

use constant WAITING_FOR_EXECUTION => 0;
use constant START                 => 1;
use constant DONE                  => 2;

sub check_below_minimum_stock {
  my ($self) = @_;

  my $dbh = SL::DB->client->dbh;
  my $query = <<SQL;
  SELECT id, partnumber, description, rop, onhand
  FROM parts
  WHERE onhand < rop
SQL

  my $result = selectall_hashref_query($::form, $dbh, $query);

  if (scalar @$result) {
    my $error_string = t8("Missing parts:\nPartnumber\t- Name\t- Onhand\t- ROP\n");
    my @ids = ();
    foreach my $part_hash (@$result) {
      $error_string.=
          $part_hash->{partnumber}
          . "\t- " . $part_hash->{description}
          . "\t- " . $part_hash->{onhand}
          . "\t- " . $part_hash->{rop}
          . "\n";
      push @ids, $part_hash->{id};
    }
    $self->{errors} = $error_string;
    $self->{ids}    = \@ids;
  }
  return;
}

sub _email_user {
  my ($self) = @_;
  return unless ($self->{config} && $self->{config}->{send_email_to});
  SL::DB::Manager::AuthUser->find_by(login => $self->{config}->{send_email_to})->get_config_value('email');
}


sub send_email {
  my ($self) = @_;

  my $email = $self->{job_obj}->data_as_hash->{mail_to} || $self->_email_user || undef;
  return unless $email;

  # additional email
  $email .= " " . $self->{job_obj}->data_as_hash->{additional_email} if $self->{job_obj}->data_as_hash->{additional_email} =~ m/(\S+)@(\S+)$/;

  my ($output, $content_type) = $self->_prepare_report;

  my $mail              = Mailer->new;
  $mail->{from}         = $self->{config}->{email_from};
  $mail->{to}           = $email;
  $mail->{subject}      = $self->{config}->{email_subject};
  $mail->{content_type} = $content_type;
  $mail->{message}      = $$output;

  my $err = $mail->send;

  if ($err) {
    $self->{errors} .= t8('Mailer error #1', $err);
  }

  return
}

sub _prepare_report {
  my ($self) = @_;

  my $template = Template->new({ 'INTERPOLATE' => 0,
                                 'EVAL_PERL'   => 0,
                                 'ABSOLUTE'    => 1,
                                 'CACHE_SIZE'  => 0,
                               });

  return unless $template;
  my $email_template = $self->{config}->{email_template};
  my $filename       = $email_template || ( (SL::DB::Default->get->templates || "templates/mails") . "/below_minimum_stock/error_email.html" );
  my $content_type   = $filename =~ m/.html$/ ? 'text/html' : 'text/plain';

  my @ids = @{$self->{ids}};
  my @parts = @{SL::DB::Manager::Part->get_all(where => [id => @ids])};


  my $table_head = html_tag('tr',
    html_tag('th', t8('Partnumber')) .
    html_tag('th', t8('ROP')) .
    html_tag('th', t8('Onhand'))
  );

  my $table_body;

  $table_body .= html_tag('tr', $_ ) for
    map {
      html_tag('td',
        link_tag(
          $ENV{HTTP_ORIGIN} . $ENV{REQUEST_URI}
          . '?action=Part/edit'
          . '&part.id=' . escape($_->id)
          # text
          , $_->partnumber
        )
      ).
      html_tag('td', $_->rop).
      html_tag('td', $_->onhand)
    } @parts;

  my %params = (
    SELF  => $self,
    PARTS => \@parts,
    part_table => html_tag('table', $table_head . $table_body),
  );

  my $output;
  $template->process($filename, \%params, \$output) || die $template->error;

  return (\$output, $content_type);
}

sub run {
  my ($self, $job_obj) = @_;
  $self->{job_obj} = $job_obj;

  $job_obj->set_data(status => START())->save;

  $self->{config} = $::lx_office_conf{check_below_minimum_stock} || {};

  $self->check_below_minimum_stock();

  if ($self->{errors}) {
      # on error we have to inform the user
      $self->send_email();
      die $self->{errors};
  }

  $job_obj->set_data(status => DONE())->save;
  return ;
}

1;

__END__

=head1 NAME

SL::BackgroundJob::CheckMinimumStock - Checks for all parts if on hand is greater
as minimum stock (onhand > rop)

=head1 SYNOPSIS

  use SL::BackgroundJob::CheckMinimumStock;
  SL::BackgroundJob::CheckMinimumStock->new->run;;

=cut
