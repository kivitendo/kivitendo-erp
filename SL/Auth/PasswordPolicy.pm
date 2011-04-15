package SL::Auth::PasswordPolicy;

use strict;

use parent qw(Rose::Object);

use constant OK                   =>   0;
use constant TOO_SHORT            =>   1;
use constant TOO_LONG             =>   2;
use constant MISSING_LOWERCASE    =>   4;
use constant MISSING_UPPERCASE    =>   8;
use constant MISSING_DIGIT        =>  16;
use constant MISSING_SPECIAL_CHAR =>  32;
use constant INVALID_CHAR         =>  64;
use constant WEAK                 => 128;

use Rose::Object::MakeMethods::Generic
(
 'scalar --get_set_init' => 'config',
);

sub verify {
  my ($self, $password, $is_admin) = @_;

  my $cfg = $self->config;
  return OK() unless $cfg && %{ $cfg };
  return OK() if $is_admin && $cfg->{disable_policy_for_admin};

  my $result = OK();
  $result |= TOO_SHORT()            if $cfg->{min_length}                && (length($password) < $cfg->{min_length});
  $result |= TOO_LONG()             if $cfg->{max_length}                && (length($password) > $cfg->{max_length});
  $result |= MISSING_LOWERCASE()    if $cfg->{require_lowercase}         && $password !~ m/[a-z]/;
  $result |= MISSING_UPPERCASE()    if $cfg->{require_uppercase}         && $password !~ m/[A-Z]/;
  $result |= MISSING_DIGIT()        if $cfg->{require_digit}             && $password !~ m/[0-9]/;
  $result |= MISSING_SPECIAL_CHAR() if $cfg->{require_special_character} && $password !~ $cfg->{special_characters_re};
  $result |= INVALID_CHAR()         if $cfg->{invalid_characters_re}     && $password =~ $cfg->{invalid_characters_re};

  if ($cfg->{use_cracklib}) {
    require Crypt::Cracklib;
    $result |= WEAK() if !Crypt::Cracklib::check($password);
  }

  return $result;
}

sub errors {
  my ($self, $result) = @_;

  my @errors;

  push @errors, $::locale->text('The password is too short (minimum length: #1).', $self->config->{min_length}) if $result & TOO_SHORT();
  push @errors, $::locale->text('The password is too long (maximum length: #1).',  $self->config->{max_length}) if $result & TOO_LONG();
  push @errors, $::locale->text('A lower-case character is required.')                                          if $result & MISSING_LOWERCASE();
  push @errors, $::locale->text('An upper-case character is required.')                                         if $result & MISSING_UPPERCASE();
  push @errors, $::locale->text('A digit is required.')                                                         if $result & MISSING_DIGIT();
  push @errors, $::locale->text('The password is weak (e.g. it can be found in a dictionary).')                 if $result & WEAK();

  if ($result & MISSING_SPECIAL_CHAR()) {
    my $char_list = join ' ', sort split(m//, $self->config->{special_characters});
    push @errors, $::locale->text('A special character is required (valid characters: #1).', $char_list);
  }

  if (($result & INVALID_CHAR())) {
    my $char_list = join ' ', sort split(m//, $self->config->{ $self->config->{invalid_characters} ? 'invalid_characters' : 'valid_characters' });
    push @errors, $::locale->text('An invalid character was used (invalid characters: #1).', $char_list) if $self->config->{invalid_characters};
    push @errors, $::locale->text('An invalid character was used (valid characters: #1).',   $char_list) if $self->config->{valid_characters};
  }

  return @errors;
}


sub init_config {
  my ($self) = @_;

  my %cfg = %{ $::lx_office_conf{password_policy} || {} };

  $cfg{valid_characters}      =~ s/[ \n\r]//g if $cfg{valid_characters};
  $cfg{invalid_characters}    =~ s/[ \n\r]//g if $cfg{invalid_characters};
  $cfg{invalid_characters_re} =  '[^' . quotemeta($cfg{valid_characters})   . ']' if $cfg{valid_characters};
  $cfg{invalid_characters_re} =  '['  . quotemeta($cfg{invalid_characters}) . ']' if $cfg{invalid_characters};
  $cfg{special_characters}    =  '!@#$%^&*()_+=[]{}<>\'"|\\,;.:?-';
  $cfg{special_characters_re} =  '[' . quotemeta($cfg{special_characters}) . ']';

  map { $cfg{"require_${_}"} = $cfg{"require_${_}"} =~ m/^(?:1|true|t|yes|y)$/i } qw(lowercase uppercase digit special_char);

  $self->config(\%cfg);
}

1;
__END__

=pod

=encoding utf8

=head1 NAME

SL::Auth::PasswordPolicy - Verify a given password against the policy
set in the configuration file

=head1 SYNOPSIS

 my $verifier = SL::Auth::PasswordPolicy->new;
 my $result   = $verifier->verify($password);
 if ($result != SL::Auth::PasswordPolicy->OK()) {
   print "Errors: " . join(' ', $verifier->errors($result)) . "\n";
 }

=head1 CONSTANTS

=over 4

=item C<OK>

Password is OK.

=item C<TOO_SHORT>

The password is too short.

=item C<TOO_LONG>

The password is too long.

=item C<MISSING_LOWERCASE>

The password is missing a lower-case character.

=item C<MISSING_UPPERCASE>

The password is missing an upper-case character.

=item C<MISSING_DIGIT>

The password is missing a digit.

=item C<MISSING_SPECIAL_CHAR>

The password is missing a special character. Special characters are
the following: ! " # $ % & ' ( ) * + , - . : ; E<lt> = E<gt> ? @ [ \ ]
^ _ { | }

=item C<INVALID_CHAR>

The password contains an invalid character.

=back

=head1 FUNCTIONS

=over 4

=item C<verify $password, $is_admin>

Checks whether or not the password matches the policy. Returns C<OK()>
if it does and an error code otherwise (binary or'ed of the error
constants).

If C<$is_admin> is trueish and the configuration specifies that the
policy checks are disabled for the administrator then C<verify> will
always return C<OK()>.

=item C<errors $code>

Returns an array of human-readable strings describing the issues set
in C<$code> which should be the result of L</verify>.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
