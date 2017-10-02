package SL::Request;

use strict;

use parent qw(Rose::Object);

use CGI qw(-no_xhtml);
use List::Util qw(first max min sum);
use List::MoreUtils qw(all any apply);
use Exporter qw(import);

use SL::Common;
use SL::MoreCommon qw(uri_encode uri_decode);
use SL::Layout::None;
use SL::Presenter;

our @EXPORT_OK = qw(flatten unflatten read_cgi_input);

use Rose::Object::MakeMethods::Generic
(
  scalar                  => [ qw(applying_database_upgrades) ],
  'scalar --get_set_init' => [ qw(cgi layout presenter is_ajax type) ],
);

sub init_cgi {
  return CGI->new({});
}

sub init_layout {
  return SL::Layout::None->new;
}

sub init_presenter {
  return SL::Presenter->new;
}

sub init_is_ajax {
  return ($ENV{HTTP_X_REQUESTED_WITH} || '') eq 'XMLHttpRequest' ? 1 : 0;
}

sub init_type {
  return 'html';
}

sub is_https {
  $ENV{HTTPS} && 'on' eq lc $ENV{HTTPS};
}

sub cache {
  my ($self, $topic, $default) = @_;

  $topic = '::' . (caller(0))[0] . "::$topic" unless $topic =~ m{^::};

  $self->{_cache}           //= {};
  $self->{_cache}->{$topic} //= ($default // {});

  return $self->{_cache}->{$topic};
}

sub _store_value {
  my ($target, $key, $value) = @_;
  my @tokens = split /((?:\[\+?\])?(?:\.)|(?:\[\+?\]))/, $key;
  my $curr;

  if (scalar @tokens) {
     $curr = \ $target->{ shift @tokens };
  }

  while (@tokens) {
    my $sep = shift @tokens;
    my $key = shift @tokens;

    $curr = \ $$curr->[$#$$curr], next   if $sep eq '[]' && @tokens;
    $curr = \ $$curr->[++$#$$curr], next if $sep eq '[]' && !@tokens;
    $curr = \ $$curr->[++$#$$curr], next if $sep eq '[+]';
    $curr = \ $$curr->[max 0, $#$$curr]  if $sep eq '[].';
    $curr = \ $$curr->[++$#$$curr]       if $sep eq '[+].';
    $curr = \ $$curr->{$key}
  }

  $$curr = $value;

  return $curr;
}

sub _input_to_hash {
  $::lxdebug->enter_sub(2);

  my ($target, $input, $log) = @_;
  my @pairs = split(/&/, $input);

  foreach (@pairs) {
    my ($key, $value) = split(/=/, $_, 2);
    next unless $key;
    _store_value($target, uri_decode($key), uri_decode($value));

    # for debugging
    $::lxdebug->add_request_params(uri_decode($key) => uri_decode($value)) if $log;
  }

  $::lxdebug->leave_sub(2);
}

sub _parse_multipart_formdata {
  my ($target, $temp_target, $input, $log) = @_;
  my ($name, $filename, $headers_done, $content_type, $boundary_found, $need_cr, $previous, $p_attachment, $encoding, $transfer_encoding);
  my $data_start = 0;

  # teach substr and length to use good ol' bytes, not 'em fancy characters
  use bytes;

  # We SHOULD honor encodings and transfer-encodings here, but as hard as I
  # looked I couldn't find a reasonably recent webbrowser that makes use of
  # these. Transfer encoding just eats up bandwidth...

  # so all I'm going to do is add a fail safe that if anyone ever encounters
  # this, it's going to croak so that debugging is easier
  $ENV{'CONTENT_TYPE'} =~ /multipart\/form-data\s*;\s*boundary\s*=\s*(.+)$/;
  my $boundary = '--' . $1;

  my $index = 0;
  my $line_length;
  foreach my $line (split m/\n/, $input) {
    $line_length = length $line;

    if ($line =~ /^\Q$boundary\E(--)?\r?$/) {
      my $last_boundary = $1;
      my $data       =  substr $input, $data_start, $index - $data_start;
      $data =~ s/\r?\n$//;

      if ($previous && !$filename && $transfer_encoding && $transfer_encoding ne 'binary') {
        ${ $previous } = Encode::decode($encoding, $data);
      } else {
        ${ $previous } = $data;
      }
      $::lxdebug->add_request_params($name, $$previous) if $log;

      undef $previous;
      undef $filename;

      $headers_done   = 0;
      $content_type   = "text/plain";
      $boundary_found = 1;
      $need_cr        = 0;
      $encoding       = 'UTF-8';
      $transfer_encoding = undef;
      last if $last_boundary;
      next;
    }

    next unless $boundary_found;

    if (!$headers_done) {
      $line =~ s/[\r\n]*$//;

      if (!$line) {
        $headers_done = 1;
        $data_start = $index + $line_length + 1;
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

        if ($name) {
          # legacy, some old upload routines expect this to be here
          $temp_target->{FILENAME} = $filename if defined $filename;

          # Name can potentially be both a normal variable or a file upload.
          # A file upload can be identified by its "filename" attribute.
          # The thing is, if a [+] clause vivifies structure in one of the
          # branches it must be done in both, or subsequent "[]" will fail
          my $temp_target_slot = _store_value($temp_target, $name);
          my $target_slot      = _store_value($target,      $name);

          # set the reference for appending of multiline data to the correct one
          $previous            = defined $filename ? $target_slot : $temp_target_slot;

          # for multiple uploads: save the attachments in a SL/Mailer like structure
          if (defined $filename) {
            my $target_attachment      = _store_value($target,      "ATTACHMENTS.$name", {});
            my $temp_target_attachment = _store_value($temp_target, "ATTACHMENTS.$name", {});

            $$target_attachment->{data}          = $previous;
            $$temp_target_attachment->{filename} = $filename;

            $p_attachment = $$temp_target_attachment;
          }
        }

        next;
      }

      if ($line =~ m|^content-type\s*:\s*(.*?)[;\$]|i) {
        $content_type = $1;
        $p_attachment->{content_type} = $1;

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
        $p_attachment->{transfer_encoding} = $transfer_encoding;

        next;
      }

      next;
    }

    next unless $previous;

  } continue {
    $index += $line_length + 1;
  }

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
        $to->{$key} = $iconv->convert("" . $from->{$key}) if defined $from->{$key} && !defined $to->{$key};
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
        $to->[$idx] = $iconv->convert("" . $from->[$idx]) if defined $from->[$idx] && !defined $to->[$idx];
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

  # yes i know, copying all those values around isn't terribly efficient, but
  # the old version of dumping everything into form and then launching a
  # tactical recode nuke at the data is still worse.

  # this way the data can at least be recoded on the fly as soon as we get to
  # know the source encoding and only in the cases where encoding may be hidden
  # among the payload we take the hit of copying the request around
  my $temp_target = { };

  # since both of these can potentially bring their encoding in INPUT_ENCODING
  # they get dumped into temp_target
  _input_to_hash($temp_target, $ENV{QUERY_STRING}, 1) if $ENV{QUERY_STRING};
  _input_to_hash($temp_target, $ARGV[0],           1) if @ARGV && $ARGV[0];

  if ($ENV{CONTENT_LENGTH}) {
    my $content;
    read STDIN, $content, $ENV{CONTENT_LENGTH};
    if ($ENV{'CONTENT_TYPE'} && $ENV{'CONTENT_TYPE'} =~ /multipart\/form-data/) {
      # multipart formdata can bring it's own encoding, so give it both
      # and let it decide on it's own
      _parse_multipart_formdata($target, $temp_target, $content, 1);
    } else {
      # normal encoding must be recoded
      _input_to_hash($temp_target, $content, 1);
    }
  }

  my $encoding     = delete $temp_target->{INPUT_ENCODING} || 'UTF-8';

  _recode_recursively(SL::Iconv->new($encoding, 'UTF-8'), $temp_target => $target) if keys %$temp_target;

  if ($target->{RESTORE_FORM_FROM_SESSION_ID}) {
    my %temp_form;
    $::auth->restore_form_from_session(delete $target->{RESTORE_FORM_FROM_SESSION_ID}, form => \%temp_form);
    _store_value($target, $_, $temp_form{$_}) for keys %temp_form;
  }

  $::lxdebug->leave_sub;

  return $target;
}

sub flatten {
  my ($source, $target, $prefix, $in_array) = @_;
  $target ||= [];

  # There are two edge cases that need attention. First: more than one hash
  # inside an array.  Only the first of each nested can have a [+].  Second: if
  # an array contains mixed values _store_value will rely on autovivification.
  # So any type change must have a [+]
  # This closure decides one recursion step AFTER an array has been found if a
  # [+] needs to be generated
  my $arr_prefix = sub {
    return $_[0] ? '[+]' : '[]' if $in_array;
    return '';
  };

  for (ref $source) {
    /^HASH$/ && do {
      my $first = 1;
      for my $key (sort keys %$source) {
        flatten($source->{$key} => $target, (defined $prefix ? $prefix . $arr_prefix->($first) . '.' : '') . $key);
        $first = 0;
      };
      next;
    };
    /^ARRAY$/ && do {
      for my $i (0 .. $#$source) {
        flatten($source->[$i] => $target, $prefix . $arr_prefix->($i == 0), '1');
      }
      next;
    };
    !$_ && do {
      die "can't flatten a pure scalar" unless defined $prefix;
      push @$target, [ $prefix . $arr_prefix->(0) => $source ];
      next;
    };
    die "unrecognized reference of a data structure $_. cannot serialize refs, globs and code yet. to serialize Form please use the method there";
  }

  return $target;
}


sub unflatten {
  my ($data, $target) = @_;
  $target ||= {};

  for my $pair (@$data) {
    _store_value($target, @$pair) if defined $pair->[0];
  }

  return $target;
}

1;

__END__

=head1 NAME

SL::Request.pm - request parsing, data serialization, request information

=head1 SYNOPSIS

This module handles unpacking of CGI parameters. It also gives
information about the request, such as whether or not it was done via AJAX,
or the requested content type.

  use SL::Request qw(read_cgi_input);

  # read cgi input depending on request type, unflatten and recode
  read_cgi_input($target_hash_ref);

  # $hashref and $new_hashref should be identical
  my $new_arrayref = flatten($hashref);
  my $new_hashref  = unflatten($new_arrayref);

  # Handle AJAX requests differently than normal requests:
  if ($::request->is_ajax) {
    $controller->render('json-mask', { type => 'json' });
  } else {
    $controller->render('full-mask');
  }

=head1 DESCRIPTION

This module provides information about the request made by the
browser.

It also handles flattening and unflattening of data for request
roundtrip purposes. kivitendo uses the format as described below:

=over 4

=item Hashes

Hash entries will be connected with a dot (C<.>). A simple hash like this

  order => {
    item     => 2,
    customer => 5
  }

will be serialized to

  [ order.item     => 2 ],
  [ order.customer => 5 ],

=item Arrays

Arrays will be marked by empty brackets (C<[]>). A hash like this

  selected_id => [ 2, 6, 8, 9 ]

will be flattened to

  [ selected_id[] => 2 ],
  [ selected_id[] => 6 ],
  [ selected_id[] => 8 ],
  [ selected_id[] => 9 ],

Since this will produce identical keys, the resulting flattened list can not be
used as a hash. It is however very easy to use this in a template to generate
input:

  [% FOREACH id = selected_ids %]
    <input type="hidden" name="selected_id[]" value="[% id | html %]">
  [% END %]

=item Nested structures

A special version of this are nested hashes in an array, which is very common.
The combined operator (C<[].>) will be used. As a special case, every time a new
array slice is started, the special convention (C<[+].>) will be used. Again this
is because it's easy to write a template with it.

So this

  order => {
    orderitems => [
      {
        id   => 1,
        part => 15
      },
      {
        id   => 2,
        part => 7
      },
    ]
  }

will be

  [ order.orderitems[+].id  => 1  ],
  [ order.orderitems[].part => 15 ],
  [ order.orderitems[+].id  => 2  ],
  [ order.orderitems[].part => 7  ],

=item Limitations

  The format currently does have certain limitations when compared to other
  serialization formats.

=over 4

=item Order

The order of serialized values matters to reconstruct arrays properly. This
should rarely be a problem if you just flatten and dump into a url or a field
of hiddens.

=item Empty Keys

The current implementation of flatten does produce correct serialization of
empty keys, but unflatten is unable to resolve these. Do no use C<''> or
C<undef> as keys. C<0> is fine.

=item Key Escaping

You cannot use the tokens C<[]>, C<[+]> and C<.> in keys. No way around it.

=item Sparse Arrays

It is not possible to serialize something like

  sparse_array => do { my $sa = []; $sa[100] = 1; $sa },

This is a feature, as perl doesn't do well with very large arrays.

=item Recursion

There is currently no support nor prevention for flattening a circular structure.

=item Custom Delimiter

No support for other delimiters, sorry.

=item Other References

No support for globs, scalar refs, code refs, filehandles and the like. These will die.

=back

=back

=head1 FUNCTIONS

=over 4

=item C<flatten HASHREF [ ARRAYREF ]>

This function will flatten the provided hash ref into the provided array ref.
The array ref may be non empty, but will be changed in this case.

The return value is the flattened array ref.

=item C<unflatten ARRAYREF [ HASHREF ]>

This function will parse the array ref, and will store the contents into the hash ref. The hash ref may be non empty, in this case any new keys will override the old ones only on leafs with same type. Type changes on a node will die.

=item C<is_ajax>

Returns trueish if the request is an XML HTTP request, also known as
an 'AJAX' request.

=item C<type>

Returns the requested content type (either C<html>, C<js> or C<json>).

=item C<layout>

Set and retrieve the layout object for the current request. Must be an instance
of L<SL::Layout::Base>. Defaults to an instance of L<SL::Layout::None>.

For more information about layouts, see L<SL::Layout::Dispatcher>.

=item C<cache $topic[, $default ]>

Caches an item for the duration of the request. C<$topic> must be an
index name referring to the thing to cache. It is used for retrieving
it later on. If C<$topic> doesn't start with C<::> then the caller's
package name is prepended to the topic. For example, if the a from
package C<SL::StuffedStuff> calls with topic = C<get_stuff> then the
actual key will be C<::SL::StuffedStuff::get_stuff>.

If no item exists in the cache for C<$topic> then it is created and
its initial value is set to C<$default>. If C<$default> is not given
(undefined) then a new, empty hash reference is created.

Returns the cached item.

=back

=head1 SPECIAL FUNCTIONS

=head2 C<_store_value()>

Parses a complex var name, and stores it in the form.

Syntax:
  _store_value($target, $key, $value);

Keys must start with a string, and can contain various tokens.
Supported key structures are:

1. simple access
  Simple key strings work as expected

  id => $form->{id}

2. hash access.
  Separating two keys by a dot (.) will result in a hash lookup for the inner value
  This is similar to the behaviour of java and templating mechanisms.

  filter.description => $form->{filter}->{description}

3. array+hashref access

  Adding brackets ([]) before the dot will cause the next hash to be put into an array.
  Using [+] instead of [] will force a new array index. This is useful for recurring
  data structures like part lists. Put a [+] into the first varname, and use [] on the
  following ones.

  Repeating these names in your template:

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

  Using brackets at the end of a name will result in the creation of a pure array.
  Note that you mustn't use [+], which is reserved for array+hash access and will
  result in undefined behaviour in array context.

  filter.status[]  => $form->{status}->[ val1, val2, ... ]

=cut
