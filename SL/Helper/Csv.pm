package SL::Helper::Csv;

use strict;
use warnings;

use version 0.77;
use Carp;
use IO::File;
use Params::Validate qw(:all);
use Text::CSV_XS;
use Rose::Object::MakeMethods::Generic scalar => [ qw(
  file encoding sep_char quote_char escape_char header profile class
  numberformat dateformat ignore_unknown_columns strict_profile _io _csv
  _objects _parsed _data _errors all_cvar_configs case_insensitive_header
) ];

use SL::Helper::Csv::Dispatcher;
use SL::Helper::Csv::Error;

# public interface

sub new {
  my $class  = shift;
  my %params = validate(@_, {
    sep_char               => { default => ';' },
    quote_char             => { default => '"' },
    escape_char            => { default => '"' },
    header                 => { type    => ARRAYREF, optional => 1 },
    profile                => { type    => HASHREF,  optional => 1 },
    file                   => 1,
    encoding               => 0,
    class                  => 0,
    numberformat           => 0,
    dateformat             => 0,
    ignore_unknown_columns => 0,
    strict_profile         => 0,
    case_insensitive_header => 0,
  });
  my $self = bless {}, $class;

  $self->$_($params{$_}) for keys %params;

  $self->_io(IO::File->new);
  $self->_csv(Text::CSV_XS->new({
    binary => 1,
    sep_char    => $self->sep_char,
    quote_char  => $self->quote_char,
    escape_char => $self->escape_char,

  }));
  $self->_errors([]);

  return $self;
}

sub parse {
  my ($self, %params) = @_;

  $self->_open_file;
  return if ! $self->_check_header;
  return if ! $self->dispatcher->parse_profile;
  return if ! $self->_parse_data;

  $self->_parsed(1);
  return $self;
}

sub get_data {
  $_[0]->_data;
}

sub get_objects {
  my ($self, %params) = @_;
  croak 'no class given'   unless $self->class;
  croak 'must parse first' unless $self->_parsed;

  $self->_make_objects unless $self->_objects;
  return wantarray ? @{ $self->_objects } : $self->_objects;
}

sub errors {
  @{ $_[0]->_errors }
}

sub check_header {
  $_[0]->_check_header;
}

# private stuff

sub _open_file {
  my ($self, %params) = @_;

  $self->encoding($self->_guess_encoding) if !$self->encoding;

  $self->_io->open($self->file, '<' . $self->_encode_layer)
    or die "could not open file " . $self->file;

  return $self->_io;
}

sub _check_header {
  my ($self, %params) = @_;
  my $header = $self->header;

  if (! $header) {
    $header = $self->_csv->getline($self->_io);

    $self->_push_error([
      $self->_csv->error_input,
      $self->_csv->error_diag,
      0,
    ]) unless $header;
  }

  # Special case: utf8 BOM.
  # certain software (namely MS Office and notepad.exe insist on prefixing
  # data with a discouraged but valid byte order mark
  # if not removed, the first header field will not be recognized
  if ($header && $header->[0] && $self->encoding =~ /utf-?8/i) {
    $header->[0] =~ s/^\x{FEFF}//;
  }

  return unless $header;

  # Special case: human stupidity
  # people insist that case sensitivity doesn't exist and try to enter all
  # sorts of stuff. at this point we've got a profile (with keys that represent
  # valid methods), and a header full of strings. if two of them match, the user
  # mopst likely meant that field, so rewrite the header
  if ($self->case_insensitive_header) {
    die 'case_insensitive_header is only possible with profile' unless $self->profile;
    my @names = (
      keys %{ $self->profile || {} },
    );
    for my $name (@names) {
      for my $i (0..$#$header) {
        $header->[$i] = $name if lc $header->[$i] eq lc $name;
      }
    }
  }

  return $self->header($header);
}

sub _parse_data {
  my ($self, %params) = @_;
  my (@data, @errors);

  $self->_csv->column_names(@{ $self->header });

  while (1) {
    my $row = $self->_csv->getline($self->_io);
    if ($row) {
      my %hr;
      @hr{@{ $self->header }} = @$row;
      push @data, \%hr;
    } else {
      last if $self->_csv->eof;
      # Text::CSV_XS 0.89 added record number to error_diag
      if (qv(Text::CSV_XS->VERSION) >= qv('0.89')) {
        push @errors, [
          $self->_csv->error_input,
          $self->_csv->error_diag,
        ];
      } else {
        push @errors, [
          $self->_csv->error_input,
          $self->_csv->error_diag,
          $self->_io->input_line_number,
        ];
      }
    }
    last if $self->_csv->eof;
  }

  $self->_data(\@data);
  $self->_push_error(@errors);

  return ! @errors;
}

sub _encode_layer {
  ':encoding(' . $_[0]->encoding . ')';
}

sub _make_objects {
  my ($self, %params) = @_;
  my @objs;

  eval "require " . $self->class;
  local $::myconfig{numberformat} = $self->numberformat if $self->numberformat;
  local $::myconfig{dateformat}   = $self->dateformat   if $self->dateformat;

  for my $line (@{ $self->_data }) {
    my $tmp_obj = $self->class->new;
    $self->dispatcher->dispatch($tmp_obj, $line);
    push @objs, $tmp_obj;
  }

  $self->_objects(\@objs);
}

sub dispatcher {
  my ($self, %params) = @_;

  $self->{_dispatcher} ||= $self->_make_dispatcher;
}

sub _make_dispatcher {
  my ($self, %params) = @_;

  die 'need a header to make a dispatcher' unless $self->header;

  return SL::Helper::Csv::Dispatcher->new($self);
}

sub _guess_encoding {
  # won't fix
  'utf-8';
}

sub _push_error {
  my ($self, @errors) = @_;
  my @new_errors = ($self->errors, map { SL::Helper::Csv::Error->new(@$_) } @errors);
  $self->_errors(\@new_errors);
}


1;

__END__

=encoding utf-8

=head1 NAME

SL::Helper::Csv - take care of csv file uploads

=head1 SYNOPSIS

  use SL::Helper::Csv;

  my $csv = SL::Helper::Csv->new(
    file        => \$::form->{upload_file},
    encoding    => 'utf-8', # undef means utf8
    sep_char    => ',',     # default ';'
    quote_char  => '\'',    # default '"'
    escape_char => '"',     # default '"'
    header      => [qw(id text sellprice word)], # see later
    profile     => { sellprice => 'sellprice_as_number' },
    class       => 'SL::DB::CsvLine',   # if present, map lines to this
  );

  my $status  = $csv->parse;
  my $hrefs   = $csv->get_data;
  my @objects = $csv->get_objects;

  my @errors  = $csv->errors;

=head1 DESCRIPTION

See Synopsis.

Text::CSV offeres already good functions to get lines out of a csv file, but in
most cases you will want those line to be parsed into hashes or even objects,
so this model just skips ahead and gives you objects.

Its basic assumptions are:

=over 4

=item You do know what you expect to be in that csv file.

This means first and foremost you have knowledge about encoding, number and
date format, csv parameters such as quoting and separation characters. You also
know what content will be in that csv and what L<Rose::DB> is responsible for
it. You provide valid header columns and their mapping to the objects.

=item You do NOT know if the csv provider yields to your expectations.

Stuff that does not work with what you expect should not crash anything, but
give you a hint what went wrong. As a result, if you remember to check for
errors after each step, you should be fine.

=item Data does not make sense. It's just data.

Almost all data imports have some type of constraints. Some data needs to be
unique, other data needs to be connected to existing data sets. This will not
happen here. You will receive a plain mapping of the data into the class tree,
nothing more.

=back

=head1 METHODS

=over 4

=item C<new> PARAMS

Standard constructor. You can use this to set most of the data.

=item C<parse>

Do the actual work. Will return true ($self actually) if success, undef if not.

=item C<get_objects>

Parse the data into objects and return those.

This method will return list or arrayref depending on context.

=item C<get_data>

Returns an arrayref of the raw lines as hashrefs.

=item C<errors>

Return all errors that came up during parsing. See error handling for detailed
information.

=back

=head1 PARAMS

=over 4

=item C<file>

The file which contents are to be read. Can be a name of a physical file or a
scalar ref for memory data.

=item C<encoding>

Encoding of the CSV file. Note that this module does not do any encoding
guessing. Know what your data is. Defaults to utf-8.

=item C<sep_char>

=item C<quote_char>

=item C<escape_char>

Same as in L<Text::CSV>

=item C<header> \@FIELDS

Can be an array of columns, in this case the first line is not used as a
header. Empty header fields will be ignored in objects.

=item C<profile> \%ACCESSORS

May be used to map header fields to custom accessors. Example:

  { listprice => listprice_as_number }

In this case C<listprice_as_number> will be used to read in values from the
C<listprice> column.

In case of a One-To-One relationsship these can also be set over
relationsships by sparating the steps with a dot (C<.>). This will work:

  { customer => 'customer.name' }

And will result in something like this:

  $obj->customer($obj->meta->relationship('customer')->class->new);
  $obj->customer->name($csv_line->{customer})

But beware, this will not try to look up anything in the database. You will
simply receive objects that represent what the profile defined. If some of
these information are unique, and should be connected to preexisting data, you
will have to do that for yourself. Since you provided the profile, it is
assumed you know what to do in this case.

If no profile is given, any header field found will be taken as is.

If the path in a profile entry is empty, the field will be subjected to
C<strict_profile> and C<case_insensitive_header> checking, will be parsed into
C<get_data>, but will not be attempted to be dispatched into objects.

=item C<class>

If present, the line will be handed to the new sub of this class,
and the return value used instead of the line itself.

=item C<ignore_unknown_columns>

If set, the import will ignore unkown header columns. Useful for lazy imports,
but deactivated by default.

=item C<case_insensitive_header>

If set, header columns will be matched against profile entries case
insensitive, and on match the profile name will be taken.

Only works if a profile is given, will die otherwise.

If both C<case_insensitive_header> and C<strict_profile> is set, matched header
columns will be accepted.

=item C<strict_profile>

If set, all columns to be parsed must be specified in C<profile>. Every header
field not listed there will be treated like an unknown column.

If both C<case_insensitive_header> and C<strict_profile> is set, matched header
columns will be accepted.

=back

=head1 ERROR HANDLING

After parsing a file all errors will be accumulated into C<errors>.
Each entry is an object with the following attributes:

 raw_input:  offending raw input,
 code:   Text::CSV error code if Text:CSV signalled an error, 0 else,
 diag:   error diagnostics,
 line:   position in line,
 col:    estimated line in file,

Note that the last entry can be off, but will give an estimate.

=head1 CAVEATS

=over 4

=item *

sep_char, quote_char, and escape_char are passed to Text::CSV on creation.
Changing them later has no effect currently.

=item *

Encoding errors are not dealt with properly.

=back

=head1 TODO

Dispatch to child objects, like this:

 $csv = SL::Helper::Csv->new(
   file  => ...
   class => SL::DB::Part,
   profile => [
     makemodel => {
       make_1  => make,
       model_1 => model,
     },
     makemodel => {
       make_2  => make,
       model_2 => model,
     },
   ]
 );

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
