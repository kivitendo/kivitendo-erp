package SL::Helper::Csv;

use strict;
use warnings;

use Carp;
use IO::File;
use Params::Validate qw(:all);
use Text::CSV;
use Rose::Object::MakeMethods::Generic scalar => [ qw(
  file encoding sep_char quote_char escape_char header profile class
  numberformat dateformat ignore_unknown_columns _io _csv _objects _parsed
  _data _errors
) ];

use SL::Helper::Csv::Dispatcher;

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
  });
  my $self = bless {}, $class;

  $self->$_($params{$_}) for keys %params;

  $self->_io(IO::File->new);
  $self->_csv(Text::CSV->new({
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
  return $self->header if $self->header;

  my $header = $self->_csv->getline($self->_io);

  $self->_push_error([
    $self->_csv->error_input,
    $self->_csv->error_diag,
    0,
  ]) unless $header;

  $self->header($header);
}

sub _parse_data {
  my ($self, %params) = @_;
  my (@data, @errors);

  $self->_csv->column_names(@{ $self->header });

  while (1) {
    my $row = $self->_csv->getline($self->_io);
    last if $self->_csv->eof;
    if ($row) {
      my %hr;
      @hr{@{ $self->header }} = @$row;
      push @data, \%hr;
    } else {
      push @errors, [
        $self->_csv->error_input,
        $self->_csv->error_diag,
        $self->_io->input_line_number,
      ];
    }
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
  my @new_errors = ($self->errors, @errors);
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
    quote_char  => ''',     # default '"'
    header      => [qw(id text sellprice word)] # see later
    profile    => { sellprice => 'sellprice_as_number' }
    class       => 'SL::DB::CsvLine',   # if present, map lines to this
  )

  my $status  = $csv->parse;
  my $hrefs   = $csv->get_data;
  my @objects = $scv->get_objects;

=head1 DESCRIPTION

See Synopsis.

Text::CSV offeres already good functions to get lines out of a csv file, but in
most cases you will want those line to be parsed into hashes or even objects,
so this model just skips ahead and gives you objects.

Encoding autodetection is not easy, and should not be trusted. Try to avoid it
if possible.

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

Return all errors that came up druing parsing. See error handling for detailed
information.

=back

=head1 PARAMS

=over 4

=item C<file>

The file which contents are to be read. Can be a name of a physical file or a
scalar ref for memory data.

=item C<encoding>

Encoding of the CSV file. Note that this module does not do any encoding
guessing.  Know what your data ist. Defaults to utf-8.

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

  { customer => customer.name }

And will result in something like this:

  $obj->customer($obj->meta->relationship('customer')->class->new);
  $obj->customer->name($csv_line->{customer})

But beware, this will not try to look up anything in the database. You will
simply receive objects that represent what the profile defined. If some of
these information are unique, and should be connected to preexisting data, you
will have to do that for yourself. Since you provided the profile, it is
assumed you know what to do in this case.

=item C<class>

If present, the line will be handed to the new sub of this class,
and the return value used instead of the line itself.

=item C<ignore_unknown_columns>

If set, the import will ignore unkown header columns. Useful for lazy imports,
but deactivated by default.

=back

=head1 ERROR HANDLING

After parsing a file all errors will be accumulated into C<errors>.

Each entry is an arrayref with the following structure:

 [
 0  offending raw input,
 1  Text::CSV error code if T:C error, 0 else,
 2  error diagnostics,
 3  position in line,
 4  estimated line in file,
 ]

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
