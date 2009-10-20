package SL::Auth::LDAP;

use English '-no_match_vars';

#use SL::Auth;

use strict;

sub new {
  $main::lxdebug->enter_sub();

  if (!defined eval "require Net::LDAP;") {
    die 'The module "Net::LDAP" is not installed.';
  }

  my $type = shift;
  my $self = {};

  $self->{auth} = shift;

  bless $self, $type;

  $main::lxdebug->leave_sub();

  return $self;
}

sub _connect {
  $main::lxdebug->enter_sub();

  my $self = shift;
  my $cfg  = $self->{auth}->{LDAP_config};

  if ($self->{ldap}) {
    $main::lxdebug->leave_sub();

    return $self->{ldap};
  }

  my $port      = $cfg->{port} || 389;
  $self->{ldap} = Net::LDAP->new($cfg->{host}, 'port' => $port);

  if (!$self->{ldap}) {
    $main::form->error($main::locale->text('The LDAP server "#1:#2" is unreachable. Please check config/authentication.pl.', $cfg->{host}, $port));
  }

  if ($cfg->{tls}) {
    my $mesg = $self->{ldap}->start_tls('verify' => 'none');
    if ($mesg->is_error()) {
      $main::form->error($main::locale->text('The connection to the LDAP server cannot be encrypted (SSL/TLS startup failure). Please check config/authentication.pl.'));
    }
  }

  if ($cfg->{bind_dn}) {
    my $mesg = $self->{ldap}->bind($cfg->{bind_dn}, 'password' => $cfg->{bind_password});
    if ($mesg->is_error()) {
      $main::form->error($main::locale->text('Binding to the LDAP server as "#1" failed. Please check config/authentication.pl.', $cfg->{bind_dn}));
    }
  }

  $main::lxdebug->leave_sub();

  return $self->{ldap};
}

sub _get_filter {
  $main::lxdebug->enter_sub();

  my $self   = shift;
  my $login  = shift;

  my ($cfg, $filter);

  $cfg    =  $self->{auth}->{LDAP_config};

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

  $main::lxdebug->leave_sub();

  return $filter;
}

sub _get_user_dn {
  $main::lxdebug->enter_sub();

  my $self   = shift;
  my $ldap   = shift;
  my $login  = shift;

  $self->{dn_cache} ||= { };

  if ($self->{dn_cache}->{$login}) {
    $main::lxdebug->leave_sub();
    return $self->{dn_cache}->{$login};
  }

  my $cfg    = $self->{auth}->{LDAP_config};

  my $filter = $self->_get_filter($login);

  my $mesg   = $ldap->search('base' => $cfg->{base_dn}, 'scope' => 'sub', 'filter' => $filter);

  if ($mesg->is_error() || (0 == $mesg->count())) {
    $main::lxdebug->leave_sub();
    return undef;
  }

  my $entry                   = $mesg->entry(0);
  $self->{dn_cache}->{$login} = $entry->dn();

  $main::lxdebug->leave_sub();

  return $self->{dn_cache}->{$login};
}

sub authenticate {
  $main::lxdebug->enter_sub();

  my $self       = shift;
  my $login      = shift;
  my $password   = shift;
  my $is_crypted = shift;

  if ($is_crypted) {
    $main::lxdebug->leave_sub();
    return SL::Auth->ERR_BACKEND();
  }

  my $ldap = $self->_connect();

  if (!$ldap) {
    $main::lxdebug->leave_sub();
    return SL::Auth->ERR_BACKEND();
  }

  my $dn = $self->_get_user_dn($ldap, $login);

  $main::lxdebug->message(LXDebug->DEBUG2(), "LDAP authenticate: dn $dn");

  if (!$dn) {
    $main::lxdebug->leave_sub();
    return SL::Auth->ERR_BACKEND();
  }

  my $mesg = $ldap->bind($dn, 'password' => $password);

  $main::lxdebug->message(LXDebug->DEBUG2(), "LDAP authenticate: bind mesg " . $mesg->error());

  $main::lxdebug->leave_sub();

  return $mesg->is_error() ? SL::Auth->ERR_PASSWORD() : SL::Auth->OK();
}

sub can_change_password {
  return 0;
}

sub change_password {
  return SL::Auth->ERR_BACKEND();
}

sub verify_config {
  $main::lxdebug->enter_sub();

  my $form   = $main::form;
  my $locale = $main::locale;

  my $self = shift;
  my $cfg  = $self->{auth}->{LDAP_config};

  if (!$cfg) {
    $form->error($locale->text('config/authentication.pl: Key "LDAP_config" is missing.'));
  }

  if (!$cfg->{host} || !$cfg->{attribute} || !$cfg->{base_dn}) {
    $form->error($locale->text('config/authentication.pl: Missing parameters in "LDAP_config". Required parameters are "host", "attribute" and "base_dn".'));
  }

  $main::lxdebug->leave_sub();
}

1;
