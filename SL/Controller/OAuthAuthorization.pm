package SL::Controller::OAuthAuthorization;

use strict;

use parent qw(SL::Controller::Base);

use SL::DB::OAuthToken;
use SL::JSON;
use SL::Locale::String;
use SL::Controller::OAuth::Microsoft;
use SL::Controller::OAuth::Atlassian;
use SL::Controller::OAuth::GoogleCal;
use SL::Helper::Flash qw(flash_later);
use SL::OAuth;


#
# actions
#

sub action_consume_authorization_code {
  my ($self) = @_;

  my $search_state = $::form->{state} or die 'Request has no state parameter';
  my $auth_code    = $::form->{code}  or die 'Request has no code parameter';

  my $tok = SL::DB::Manager::OAuthToken->find_by(tokenstate => $search_state) or die "no token with state $search_state";
  my $provider = SL::OAuth::providers()->{$tok->registration} or die "unknown provider";

  my $ret = $provider->access_token($tok, $auth_code);

  my $response_code = $ret->responseCode();
  die "Request failed, response code was: $response_code" unless $response_code == 200;

  my $content = from_json($ret->responseContent);

  die "Server returned error_code $content->{error_code}" if (exists $content->{error_code});

  $tok->set_access_refresh_token($content);
  $tok->tokenstate(undef);
  $tok->save;

  flash_later('info', t8('OAuth token received: #1, database ID #2', $tok->registration, $tok->id));
  $self->redirect_to(controller => 'OAuth', action => 'list');
}





1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::OAuthAuthorization - Client side OAuth2 authorization code handling

=head1 FUNCTIONS

=over 4

=item C<action_consume_authorization_code>

This is the controller action that is invoked from the dispatcher, when an
OAuth2 provider redirects the user's web browser to the redirect_uri. In
this case, the authorization code is transferred in the query parameter
C<code>.

=back

=head1 BUGS

When an OAuth2 provider redirects the user's web browser to our
dispatcher, the web browser does not send the session cookie as
sending the cookie would violate the SameSite=strict policy. The
user is asked to log in again and only then the controller action
C<action_consume_authorization_code> is called.  This works,
but can be unexpected for the user.

Possible solutions include:

1. Storing the session cookie just once, before redirecting to the OAuth2
provider, with SameSite=Lax.

2. Allowing unauthenticated (in the sense that no session cookie
is required) requests for just C<action_consume_authorization_code>,
processing and storing the token as implemented currently and then either
ending the request or clearing all form parameters and callbacks and
redirecting the user to us, now in compliance with the SameSite policy.
Care must be taken to prevent denial of service attacks by means of
guessing valid C<tokenstate> values of inflight tokens.

=head1 AUTHOR

Niklas Schmidt E<lt>niklas@kivitendo.deE<gt>

=cut
