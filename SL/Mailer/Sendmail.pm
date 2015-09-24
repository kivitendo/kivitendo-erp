package SL::Mailer::Sendmail;

use strict;

use Encode;
use IO::File;
use SL::Template;

use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic
(
  scalar => [ qw(myconfig mailer form status extended_status) ]
);

sub init {
  my ($self) = @_;

  Rose::Object::init(
    @_,
    status          => 'failed',
    extended_status => 'no send attempt made',
  );

  my $email         =  Encode::encode('utf-8', $self->myconfig->{email});
  $email            =~ s/[^\w\.\-\+=@]//ig;

  my %temp_form     = ( %{ $self->form }, myconfig_email => $email );
  my $template      = SL::Template::create(type => 'ShellCommand', form => \%temp_form);
  my $sendmail      = $::lx_office_conf{applications}->{sendmail} || $::lx_office_conf{mail_delivery}->{sendmail} || "sendmail -t";
  $sendmail         = $template->parse_block($sendmail);

  $self->{sendmail} = IO::File->new("|$sendmail") or do { $self->extended_status("sendmail($sendmail): $!"); die $self->extended_status; };
  $self->{sendmail}->binmode(':utf8');
}

sub start_mail {
}

sub print {
  my $self = shift;

  $self->{sendmail}->print(@_) or do { $self->extended_status("sendmail: $!"); die $self->extended_status; };
}

sub send {
  my ($self) = @_;

  $self->{sendmail}->close or do { $self->extended_status("sendmail: $!"); die $self->extended_status; };

  $self->status('ok');
  $self->extended_status('');

  delete $self->{sendmail};
}

sub keep_from_header {
  0;
}

1;
