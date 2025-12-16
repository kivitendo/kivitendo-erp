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

sub action_authcode {
  my ($self) = @_;

  my $search_state = $::form->{state} or die 'Request has no state parameter';
  my $auth_code    = $::form->{code}  or die 'Request has no code parameter';

  my $tok = SL::DB::Manager::OAuthToken->find_by(tokenstate => $search_state) or die 'unknown state';
  my $provider = SL::OAuth::providers()->{$tok->registration} or die 'unknown provider';

  my $ret = $provider->access_token($tok, $auth_code);

  my $response_code = $ret->responseCode();

  unless ($response_code >= 200 && $response_code <= 299) {
    flash_later('error', t8('Provider returned HTTP #1', $response_code));
    return $self->redirect_to(controller => 'OAuth', action => 'list');
  }

  my $content = from_json($ret->responseContent);

  if (exists $content->{error_code}) {
    flash_later('error', t8('Provider returned error code #1', $content->{error_code}));
    return $self->redirect_to(controller => 'OAuth', action => 'list');
  }

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

=item C<action_authcode>

This is the controller action that is invoked from the dispatcher, when an
OAuth2 provider redirects the user's web browser to the redirect_uri. In
this case, the authorization code is transferred in the query parameter
C<code>.

=back

=head1 AUTHOR

Niklas Schmidt E<lt>niklas@kivitendo.deE<gt>

=cut
