package SL::Request;

use strict;

use SL::Common;
use SL::MoreCommon qw(uri_encode uri_decode);
use List::Util qw(first max min sum);
use List::MoreUtils qw(all any apply);

sub _store_value {
  $::lxdebug->enter_sub(2);

  my ($target, $key, $value) = @_;
  my @tokens = split /((?:\[\+?\])?(?:\.|$))/, $key;
  my $curr;

  if (scalar @tokens) {
     $curr = \ $target->{ shift @tokens };
  }

  while (@tokens) {
    my $sep = shift @tokens;
    my $key = shift @tokens;

    $curr = \ $$curr->[++$#$$curr], next if $sep eq '[]';
    $curr = \ $$curr->[max 0, $#$$curr]  if $sep eq '[].';
    $curr = \ $$curr->[++$#$$curr]       if $sep eq '[+].';
    $curr = \ $$curr->{$key}
  }

  $$curr = $value;

  $::lxdebug->leave_sub(2);

  return $curr;
}

sub _input_to_hash {
  $::lxdebug->enter_sub(2);

  my ($target, $input) = @_;
  my @pairs = split(/&/, $input);

  foreach (@pairs) {
    my ($key, $value) = split(/=/, $_, 2);
    _store_value($target, uri_decode($key), uri_decode($value)) if ($key);
  }

  $::lxdebug->leave_sub(2);
}

sub parse_multipart_formdata {
  my ($target, $input) = @_;
  my ($name, $filename, $headers_done, $content_type, $boundary_found, $need_cr, $previous);
  my $uploads = {};

  my $boundary = '--' . $1;

  foreach my $line (split m/\n/, $input) {
    last if (($line eq "${boundary}--") || ($line eq "${boundary}--\r"));

    if (($line eq $boundary) || ($line eq "$boundary\r")) {
      ${ $previous } =~ s|\r?\n$|| if $previous;

      undef $previous;
      undef $filename;

      $headers_done   = 0;
      $content_type   = "text/plain";
      $boundary_found = 1;
      $need_cr        = 0;

      next;
    }

    next unless $boundary_found;

    if (!$headers_done) {
      $line =~ s/[\r\n]*$//;

      if (!$line) {
        $headers_done = 1;
        next;
      }

      if ($line =~ m|^content-disposition\s*:.*?form-data\s*;|i) {
        if ($line =~ m|filename\s*=\s*"(.*?)"|i) {
          $filename = $1;
          substr $line, $-[0], $+[0] - $-[0], "";
        }

        if ($line =~ m|name\s*=\s*"(.*?)"|i) {
          $name = $1;
          substr $line, $-[0], $+[0] - $-[0], "";
        }

        $previous           = _store_value($uploads, $name, '') if ($name);
        $target->{FILENAME} = $filename if ($filename);

        next;
      }

      if ($line =~ m|^content-type\s*:\s*(.*?)$|i) {
        $content_type = $1;
      }

      next;
    }

    next unless $previous;

    ${ $previous } .= "${line}\n";
  }

  ${ $previous } =~ s|\r?\n$|| if $previous;

  $::lxdebug->leave_sub(2);

}

sub _request_to_hash {
  $::lxdebug->enter_sub(2);

  my ($target, $input) = @_;
  my $uploads;

  if (!$ENV{'CONTENT_TYPE'}
      || ($ENV{'CONTENT_TYPE'} !~ /multipart\/form-data\s*;\s*boundary\s*=\s*(.+)$/)) {

   $uploads = { };
    _input_to_hash($target, $input);

  } else {
   $uploads = _parse_multipart_formdata($target, $input);
  }

  $main::lxdebug->leave_sub(2);
  return $uploads;
}

sub _recode_recursively {
  $main::lxdebug->enter_sub();
  my ($iconv, $param) = @_;

  if (any { ref $param eq $_ } qw(Form HASH)) {
    foreach my $key (keys %{ $param }) {
      if (!ref $param->{$key}) {
        # Workaround for a bug: converting $param->{$key} directly
        # leads to 'undef'. I don't know why. Converting a copy works,
        # though.
        $param->{$key} = $iconv->convert("" . $param->{$key});
      } else {
        _recode_recursively($iconv, $param->{$key});
      }
    }

  } elsif (ref $param eq 'ARRAY') {
    foreach my $idx (0 .. scalar(@{ $param }) - 1) {
      if (!ref $param->[$idx]) {
        # Workaround for a bug: converting $param->[$idx] directly
        # leads to 'undef'. I don't know why. Converting a copy works,
        # though.
        $param->[$idx] = $iconv->convert("" . $param->[$idx]);
      } else {
        _recode_recursively($iconv, $param->[$idx]);
      }
    }
  }
  $main::lxdebug->leave_sub();
}

sub read_cgi_input {
  $::lxdebug->enter_sub;

  my ($target) = @_;

  _input_to_hash($target, $ENV{QUERY_STRING}) if $ENV{QUERY_STRING};
  _input_to_hash($target, $ARGV[0])           if @ARGV && $ARGV[0];

  my $uploads;
  if ($ENV{CONTENT_LENGTH}) {
    my $content;
    read STDIN, $content, $ENV{CONTENT_LENGTH};
    $uploads = _request_to_hash($target, $content);
  }

  if ($target->{RESTORE_FORM_FROM_SESSION_ID}) {
    my %temp_form;
    $::auth->restore_form_from_session(delete $target->{RESTORE_FORM_FROM_SESSION_ID}, form => \%temp_form);
    _input_to_hash($target, join '&', map { uri_encode($_) . '=' . uri_encode($temp_form{$_}) } keys %temp_form);
  }

  my $db_charset   = $::lx_office_conf{system}->{dbcharset} || Common::DEFAULT_CHARSET;
  my $encoding     = delete $target->{INPUT_ENCODING} || $db_charset;

  _recode_recursively(SL::Iconv->new($encoding, $db_charset), $target);

  map { $target->{$_} = $uploads->{$_} } keys %{ $uploads } if $uploads;

  $::lxdebug->leave_sub;

  return $target;
}

1;

__END__

=head1 NAME

SL::Form.pm - main data object.

=head1 SYNOPSIS

This module handles unpacking of cgi parameters. usually you donÄt want to call
anything in here directly,

  SL::Request::read_cgi_input($target_hash_ref);

=head1 SPECIAL FUNCTIONS

=head2 C<_store_value()>

parses a complex var name, and stores it in the form.

syntax:
  $form->_store_value($key, $value);

keys must start with a string, and can contain various tokens.
supported key structures are:

1. simple access
  simple key strings work as expected

  id => $form->{id}

2. hash access.
  separating two keys by a dot (.) will result in a hash lookup for the inner value
  this is similar to the behaviour of java and templating mechanisms.

  filter.description => $form->{filter}->{description}

3. array+hashref access

  adding brackets ([]) before the dot will cause the next hash to be put into an array.
  using [+] instead of [] will force a new array index. this is useful for recurring
  data structures like part lists. put a [+] into the first varname, and use [] on the
  following ones.

  repeating these names in your template:

    invoice.items[+].id
    invoice.items[].parts_id

  will result in:

    $form->{invoice}->{items}->[
      {
        id       => ...
        parts_id => ...
      },
      {
        id       => ...
        parts_id => ...
      }
      ...
    ]

4. arrays

  using brackets at the end of a name will result in a pure array to be created.
  note that you mustn't use [+], which is reserved for array+hash access and will
  result in undefined behaviour in array context.

  filter.status[]  => $form->{status}->[ val1, val2, ... ]

=cut
