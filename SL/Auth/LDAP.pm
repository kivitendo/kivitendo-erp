package SL::Auth::LDAP;

use English '-no_match_vars';

use SL::Auth::Constants qw(:all);

use strict;

sub new {
  if (!defined eval "require Net::LDAP;") {
    die 'The module "Net::LDAP" is not installed.';
  }

  my $type        = shift;
  my $self        = {};
  $self->{config} = shift;

  bless $self, $type;

  return $self;
}

sub reset {
  my ($self) = @_;
  $self->{ldap}     = undef;
  $self->{dn_cache} = { };
}

sub _connect {
  my $self = shift;
  my $cfg  = $self->{config};

  return $self->{ldap} if $self->{ldap};

  my $port = $cfg->{port} || 389;
  my $ldap = Net::LDAP->new($cfg->{host}, port => $port, timeout => $cfg->{timeout} || 10);

  if (!$ldap) {
    $::lxdebug->warn($main::locale->text('The LDAP server "#1:#2" is unreachable. Please check config/kivitendo.conf.', $cfg->{host}, $port));
    return undef;
  }

  if ($cfg->{tls}) {
    my $mesg = $ldap->start_tls(verify => $cfg->{verify} // 'require');
    if ($mesg->is_error()) {
      $::lxdebug->warn($main::locale->text('The connection to the LDAP server cannot be encrypted (SSL/TLS startup failure). Please check config/kivitendo.conf.'));
      return undef;
    }
  }

  if ($cfg->{bind_dn}) {
    my $mesg = $ldap->bind($cfg->{bind_dn}, 'password' => $cfg->{bind_password});
    if ($mesg->is_error()) {
      $::lxdebug->warn($main::locale->text('Binding to the LDAP server as "#1" failed. Please check config/kivitendo.conf.', $cfg->{bind_dn}));
      return undef;
    }
  }

  $self->{ldap} = $ldap;

  return $self->{ldap};
}

sub _get_filter {
  my $self   = shift;
  my $login  = shift;

  my ($cfg, $filter);

  $cfg    =  $self->{config};

  $filter =  "$cfg->{filter}";
  $filter =~ s|^\s+||;
  $filter =~ s|\s+$||;

  $login  =~ s|\\|\\\\|g;
  $login  =~ s|\(|\\\(|g;
  $login  =~ s|\)|\\\)|g;
  $login  =~ s|\*|\\\*|g;
  $login  =~ s|\x00|\\00|g;

  if ($filter =~ m|<\%login\%>|) {
    substr($filter, $LAST_MATCH_START[0], $LAST_MATCH_END[0] - $LAST_MATCH_START[0]) = $login;

  } elsif ($filter) {
    if ((substr($filter, 0, 1) ne '(') || (substr($filter, -1, 1) ne ')')) {
      $filter = "($filter)";
    }

    $filter = "(&${filter}($cfg->{attribute}=${login}))";

  } else {
    $filter = "$cfg->{attribute}=${login}";

  }

  return $filter;
}

sub _get_user_dn {
  my $self   = shift;
  my $ldap   = shift;
  my $login  = shift;

  $self->{dn_cache} ||= { };

  return $self->{dn_cache}->{$login} if $self->{dn_cache}->{$login};

  my $cfg    = $self->{config};

  my $filter = $self->_get_filter($login);

  my $mesg   = $ldap->search('base' => $cfg->{base_dn}, 'scope' => 'sub', 'filter' => $filter);

  return undef if $mesg->is_error || !$mesg->count();

  my $entry                   = $mesg->entry(0);
  $self->{dn_cache}->{$login} = $entry->dn();

  return $self->{dn_cache}->{$login};
}

sub authenticate {
  my $self       = shift;
  my $login      = shift;
  my $password   = shift;
  my $is_crypted = shift;

  return ERR_BACKEND if $is_crypted;

  my $ldap = $self->_connect();

  return ERR_BACKEND if !$ldap;

  my $dn = $self->_get_user_dn($ldap, $login);

  $main::lxdebug->message(LXDebug->DEBUG2(), "LDAP authenticate: dn $dn");

  return ERR_BACKEND if !$dn;

  my $mesg = $ldap->bind($dn, 'password' => $password);

  $main::lxdebug->message(LXDebug->DEBUG2(), "LDAP authenticate: bind mesg " . $mesg->error());

  return $mesg->is_error() ? ERR_PASSWORD : OK;
}

sub can_change_password {
  return 0;
}

sub requires_cleartext_password {
  return 1;
}

sub change_password {
  return ERR_BACKEND;
}

sub verify_config {
  my $form   = $main::form;
  my $locale = $main::locale;

  my $self = shift;
  my $cfg  = $self->{config};

  if (!$cfg) {
    $form->error($locale->text('config/kivitendo.conf: Key "authentication/ldap" is missing.'));
  }

  if (!$cfg->{host} || !$cfg->{attribute} || !$cfg->{base_dn}) {
    $form->error($locale->text('config/kivitendo.conf: Missing parameters in "authentication/ldap". Required parameters are "host", "attribute" and "base_dn".'));
  }
}

1;
