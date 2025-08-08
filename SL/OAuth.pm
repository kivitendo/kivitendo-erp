package SL::OAuth;

use strict;

use List::MoreUtils qw(all);
use SL::DB::OAuthToken;

my %providers = (
  atlassian_jira  => 'SL::Controller::OAuth::Atlassian',
  google_cal      => 'SL::Controller::OAuth::GoogleCal',
  microsoft_email => 'SL::Controller::OAuth::Microsoft',
);


sub providers {
  \%providers;
}

sub configured_providers {
  my %configured = %providers{
    grep {
      my $key = "oauth2_$_";
      all { $::lx_office_conf{$key}{$_} } qw(client_id client_secret redirect_uri)
    } keys %providers
  };

  \%configured;
}

sub access_token_for {
  my ($target, %params) = @_;

  my $token = SL::DB::Manager::OAuthToken->find_by(
    tokenstate   => undef,
    registration => $target,
    email        => $params{email},
    or           => [
      (employee_id => SL::DB::Manager::Employee->current->id), # token for current user
      (employee_id => undef), # client wide token
    ],
    sort_by      => 'employee_id ASC NULLS LAST',
  );

  SL::X::OAuth::MissingToken->throw() unless $token;

  refresh($token) unless $token->is_valid();

  $token->access_token;
}

sub refresh {
  my ($tok) = @_;
  my $provider = SL::OAuth::providers()->{$tok->registration} or die "unknown provider";

  my $ret = $provider->refresh($tok);

  my $response_code = $ret->responseCode();
  SL::X::OAuth::RefreshFailed->throw() unless $response_code == 200;

  my $content = from_json($ret->responseContent());
  SL::X::OAuth::RefreshFailed->throw() if exists $content->{error_code};

  $tok->set_access_refresh_token($content);
  $tok->save;
}

__END__

=pod

=encoding utf8

=head1 NAME

SL::OAuth - Client side OAuth2 token management

=head1 SYNOPSIS

  use Mail::IMAPClient;
  use SL::OAuth;

  sub oauth_imap_get_folders {

    my $server       = 'mail.domain';
    my $username     = 'kivitendo.test@your.domain';

    my $access_token = SL::OAuth::access_token_for('microsoft_email', email => $username);

    my $sasl_string  = encode_base64("user=$username\x01auth=Bearer $access_token\x01\x01", '');

    my $imap = Mail::IMAPClient->new(
      Server   => $server,
      User     => $username,
      Ssl      => 1,
      Uid      => 1,
    ) or die "Cannot connect $@";

    $imap->authenticate('XOAUTH2', sub { return $sasl_string; }) or die('Auth error: ' . $imap->LastError);

    my @folders = @{$imap->folders or die 'List folders: ' . $imap->LastError};

    return \@folders;
  }

=head1 FUNCTIONS

=over 4

=item C<access_token_for>

This is a common function that retrieves an OAuth access token from
the database, refreshing it in the case it expired. The first access
token valid for the currently logged in user matching the given target
is returned. If no such token exists, the first matching access token
which is valid client wiede is returned, if existing.

If no token is found or the refresh of a found but expired token
fails, the corresponing exception C<SL::X::OAuth::MissingToken> or
C<SL::X::OAuth::RefreshFailed> is thrown.

=back

=head1 TOKENSTATE

Each SL::DB::OAuthToken is in one of two distinct states: inflight
or complete.  When a user creates a new token, the token is first
stored in the database with a random C<tokenstate> value and a URL is
presented to the user in order to asynchronously perform a request to
the OAuth2 provider, retrieving an authentication code. Finally, using
the authentication code, an access token and optionally a refresh token
are retrieved from the provider.

This means that all tokens with a non-null C<tokenstate> are inflight
and conversely all tokens with a null/undef C<tokenstate> are completed.
Only completed tokens can be used for authentication.


=head1 LITERATURE

Alexander Perlis' Mutt OAuth2 token management script provides a rather
compact implementation in Python for fetching a single OAuth2 token
(no state parameter handling)


=head1 AUTHOR

Niklas Schmidt E<lt>niklas@kivitendo.deE<gt>

=cut
