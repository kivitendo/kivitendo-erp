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

sub _parse_multipart_formdata {
  my ($target, $temp_target, $input) = @_;
  my ($name, $filename, $headers_done, $content_type, $boundary_found, $need_cr, $previous, $encoding, $transfer_encoding);

  # We SHOULD honor encodings and transfer-encodings here, but as hard as I
  # looked I couldn't find a reasonably recent webbrowser that makes use of
  # these. Transfer encoding just eats up bandwidth...

  # so all I'm going to do is add a fail safe that if anyone ever encounters
  # this, it's going to croak so that debugging is easier
  $ENV{'CONTENT_TYPE'} =~ /multipart\/form-data\s*;\s*boundary\s*=\s*(.+)$/;
  my $boundary = '--' . $1;

  foreach my $line (split m/\n/, $input) {
    last if (($line eq "${boundary}--") || ($line eq "${boundary}--\r"));

    if (($line eq $boundary) || ($line eq "$boundary\r")) {
      ${ $previous } =~ s|\r?\n$|| if $previous;
      ${ $previous } =  Encode::decode($encoding, $$previous) if $previous && !$filename && !$transfer_encoding eq 'binary';

      undef $previous;
      undef $filename;

      $headers_done   = 0;
      $content_type   = "text/plain";
      $boundary_found = 1;
      $need_cr        = 0;
      $encoding       = $::lx_office_conf{system}->{dbcharset} || Common::DEFAULT_CHARSET;
      $transfer_encoding = undef;

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

        $previous                = _store_value($filename ? $target : $temp_target, $name, '') if ($name);
        $temp_target->{FILENAME} = $filename if ($filename);

        next;
      }

      if ($line =~ m|^content-type\s*:\s*(.*?)[;\$]|i) {
        $content_type = $1;

        if ($content_type =~ /^text/ && $line =~ m|;\s*charset\s*:\s*("?)(.*?)\1$|i) {
          $encoding = $2;
        }

        next;
      }

      if ($line =~ m|^content-transfer-encoding\s*=\s*(.*?)$|i) {
        $transfer_encoding = lc($1);
        if ($transfer_encoding  && $transfer_encoding !~ /^[78]bit|binary$/) {
          die 'Transfer encodings beyond 7bit/8bit and binary are not implemented.';
        }

        next;
      }

      next;
    }

    next unless $previous;

    ${ $previous } .= "${line}\n";
  }

  ${ $previous } =~ s|\r?\n$|| if $previous;

  $::lxdebug->leave_sub(2);
}

sub _recode_recursively {
  $::lxdebug->enter_sub;
  my ($iconv, $from, $to) = @_;

  if (any { ref $from eq $_ } qw(Form HASH)) {
    for my $key (keys %{ $from }) {
      if (!ref $from->{$key}) {
        # Workaround for a bug: converting $from->{$key} directly
        # leads to 'undef'. I don't know why. Converting a copy works,
        # though.
        $to->{$key} = $iconv->convert("" . $from->{$key});
      } else {
        $to->{$key} ||= {} if 'HASH'  eq ref $from->{$key};
        $to->{$key} ||= [] if 'ARRAY' eq ref $from->{$key};
        _recode_recursively($iconv, $from->{$key}, $to->{$key});
      }
    }

  } elsif (ref $from eq 'ARRAY') {
    foreach my $idx (0 .. scalar(@{ $from }) - 1) {
      if (!ref $from->[$idx]) {
        # Workaround for a bug: converting $from->[$idx] directly
        # leads to 'undef'. I don't know why. Converting a copy works,
        # though.
        $from->[$idx] = $iconv->convert("" . $from->[$idx]);
      } else {
        $to->[$idx] ||= {} if 'HASH'  eq ref $from->[$idx];
        $to->[$idx] ||= [] if 'ARRAY' eq ref $from->[$idx];
        _recode_recursively($iconv, $from->[$idx], $to->[$idx]);
      }
    }
  }
  $main::lxdebug->leave_sub();
}

sub read_cgi_input {
  $::lxdebug->enter_sub;

  my ($target) = @_;
  my $db_charset   = $::lx_office_conf{system}->{dbcharset} || Common::DEFAULT_CHARSET;

  # yes i know, copying all those values around isn't terribly efficient, but
  # the old version of dumping everything into form and then launching a
  # tactical recode nuke at the data is still worse.

  # this way the data can at least be recoded on the fly as soon as we get to
  # know the source encoding and only in the cases where encoding may be hidden
  # among the payload we take the hit of copying the request around
  my $temp_target = { };

  # since both of these can potentially bring their encoding in INPUT_ENCODING
  # they get dumped into temp_target
  _input_to_hash($temp_target, $ENV{QUERY_STRING}) if $ENV{QUERY_STRING};
  _input_to_hash($temp_target, $ARGV[0])           if @ARGV && $ARGV[0];

  if ($ENV{CONTENT_LENGTH}) {
    my $content;
    read STDIN, $content, $ENV{CONTENT_LENGTH};
    if ($ENV{'CONTENT_TYPE'} && $ENV{'CONTENT_TYPE'} =~ /multipart\/form-data/) {
      # multipart formdata can bring it's own encoding, so give it both
      # and let ti decide on it's own
      _parse_multipart_formdata($target, $temp_target, $content);
    } else {
      # normal encoding must be recoded
      _input_to_hash($temp_target, $content);
    }
  }

  my $encoding     = delete $temp_target->{INPUT_ENCODING} || $db_charset;

  _recode_recursively(SL::Iconv->new($encoding, $db_charset), $temp_target => $target) if keys %$target;

  if ($target->{RESTORE_FORM_FROM_SESSION_ID}) {
    my %temp_form;
    $::auth->restore_form_from_session(delete $target->{RESTORE_FORM_FROM_SESSION_ID}, form => \%temp_form);
    _store_value($target, $_, $temp_form{$_}) for keys %temp_form;
  }

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
