package SL::KIX18Client;

use strict;

use Data::Dumper;
use Encode qw(encode);
use Params::Validate qw(:all);
use REST::Client;
use Try::Tiny;

use SL::JSON;
use SL::Locale::String qw(t8);

use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(connector) ],
);


sub create_ticket_with_article {
  my $self = shift;
  validate(
    @_, {
          ticket  => { type => HASHREF },
          article => { type => HASHREF },
        }
  );
  my %params = @_;

  $params{article}{TicketID} = $self->create_ticket(%{ $params{ticket} });
  $self->create_article(%{ $params{article} });
  return $params{article}{TicketID};
}

sub get_ticket {
  my $self = shift;
  die "Invalid connection state" unless $self->connector->can('GET');

  validate(
    @_, {
          ticket_id => 1,
        }
  );
  my %params = @_;

  my $ret = _decode_and_status_code($self->connector->GET("tickets/$params{ticket_id}"));

  return $ret;
}

sub create_ticket {
  my $self = shift;
  die "Invalid connection state" unless $self->connector->can('POST');

  validate(
    @_, {
          Title => 1,
        }
  );
  my %params = @_;

  # create ticket with title
  my %t_params = ();
  foreach (keys %params) {
    $t_params{Ticket}{$_} = _u8($params{$_});
  }
  my $ret = _decode_and_status_code($self->connector->POST('tickets', encode_json(\%t_params)));

  return $ret->{TicketID};
}

sub create_article {
  my $self = shift;
  die "Invalid connection state" unless $self->connector->can('POST');

  validate(
    @_, {
          Subject => 1,
          Body    => 1,
          Channel     => { type => SCALAR, default => 'note'                      },
          Charset     => { type => SCALAR, default => 'utf-8'                     },
          MimeType    => { type => SCALAR, default => 'text/html',               },
          ContentType => { type => SCALAR, default => 'text/html; charset=utf-8' },

          TicketID => { callbacks => {
                         'is an integer' => sub {
                            return 1 if $_[0] =~ /^-?[1-9][0-9]*$/;
                            die "$_[0] is not a valid integer value";
                          },
                        }
                      },
        }
  );
  my %params = @_;

  # validate sets the params only if the caller passes them ...
  # therefore the defaults need to be defined again:
  $params{Channel}     //= 'note';
  $params{Charset}     //= 'utf-8';
  $params{MimeType}    //= 'text/html';
  $params{ContentType} //= 'text/html; charset=utf-8';

  my %a_params = ();
  foreach (keys %params) {
    next if $_ eq 'TicketID'; # TicketID is set in POST URL
    $a_params{Article}{$_} = $params{Charset} eq 'utf-8' ? _u8($params{$_}) : $params{$_};
  }

  my $ret = _decode_and_status_code($self->connector->POST("tickets/$params{TicketID}/articles", encode_json(\%a_params)));
  return $ret->{ArticleID};
}


sub init_connector {
  my ($self) = @_;
  my $config = $::lx_office_conf{kix18};

  foreach my $key (qw(kix_api_url kix_api_user kix_api_user_pw)) {
    die ("missing parameter: $key") unless $config->{$key};
  }

  my $protocol = $config->{kix_api_url} =~ /(^https:\/\/|^http:\/\/)/ ? '' : $config->{protocol} . '://';
  my $client   = REST::Client->new(host => $config->{kix_api_url});

  $client->getUseragent()->proxy([$config->{protocol}], $config->{proxy}) if $config->{proxy};

  $client->addHeader('Content-Type', 'application/json');
  $client->addHeader('charset',      'UTF-8'           );
  $client->addHeader('Accept',       'application/json');

  my %auth_req = (
                   UserLogin     => $config->{kix_api_user},
                   Password      => $config->{kix_api_user_pw},
                   UserType      => "Agent",
                 );

  my $ret = $client->POST('auth', encode_json(\%auth_req));
  die $ret->responseContent() unless (201 == $ret->responseCode());

  my $token = decode_json($ret->responseContent())->{Token};
  die "No Auth-Token received" unless $token;

  # persist auth token
  $client->addHeader('Authorization' => 'Token ' . $token);

  return $client;
}

# internal methods

sub _decode_and_status_code {
  my ($ret) = @_;

  die t8("Unsuccessful HTTP return code: #1 Details: #2", $ret->responseCode(), $ret->responseContent())
    unless $ret->responseCode() == 201 || $ret->responseCode() == 200;

  try {
   return decode_json($ret->responseContent());
  } catch { t8("Invalid JSON format"); }

}

sub _u8 {
  my ($value) = @_;
  return encode('UTF-8', $value // '');
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::KIX18Client a REST Client for the KIX18 restful API

=head1 SYNOPSIS

Needs at least three parameters in kivitendo.conf in
the section kix18:

C<kix_api_user>
C<kix_api_user_pw>
C<kix_api_url>

With these parameters the init_connector method will
try to authenticate against a given kix18 REST-Server.
If successfull the client is able to do RESTful calls to the server, i.e. create
tickets.

=head1 DESCRIPTION

For a general documentation of the RESTful API for KIX take a look here:
https://github.com/kix-service-software/kix-backend/blob/master/doc/API/V1/KIX.html



=head1 AVAILABLE METHODS

=over 4

=item C<get_ticket $ticket_id>

Gets the specific ticket with $ticket_id and returns all standard ticket data
as a nested hash structure.

=item C<create_ticket $Title>

Creates a Ticket with the named param Title. Returns the ID of the created Ticket.
No more parameters are accepted, if needed add optional params in the validation

=item C<create_article $TicketID $Subject $Body>

Creates an article for the given TicketID. Needs a Subject and a Body as
named Params. Defaults to Channel 'note' with encoding UTF8.

=item C<create_ticket_with_article \%ticket \%article>

Calls C<create_ticket> and C<create_article> Expects the mandantory params
for the calls in the hashref ticket and article.

=back

=head1 AUTHOR

Jan BürenE<lt>jan@kivitendo.deE<gt>

=cut
