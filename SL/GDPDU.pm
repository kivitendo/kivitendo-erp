package SL::GDPDU;

# TODO:
# optional: background jobable

use strict;
use utf8;

use parent qw(Rose::Object);

use Text::CSV_XS;
use XML::Writer;
use Archive::Zip;
use File::Temp ();
use File::Spec ();
use List::UtilsBy qw(partition_by);

use SL::DB::Helper::ALL; # since we work on meta data, we need everything
use SL::DB::Helper::Mappings;
use SL::Locale::String qw(t8);

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(from to tables writer company location) ],
  'scalar --get_set_init' => [ qw(files tempfiles export_ids) ],
);

# in this we find:
# key:         table name
# name:        short name, translated
# description: long description, translated
# transdate:   column used to filter from/to, empty if table is filtered otherwise
# keep:        arrayref of columns that should be saved for further referencing
# tables:      arrayref with one column and one or many table.column references that were kept earlier
my %known_tables = (
  ar                    => { name => t8('Invoice'),                 description => t8('Sales Invoices and Accounts Receivables'),   keep => [ qw(id customer_id vendor_id) ], transdate => 'transdate', },
  ap                    => { name => t8('Purchase Invoice'),        description => t8('Purchase Invoices and Accounts Payables'),   keep => [ qw(id customer_id vendor_id) ], transdate => 'transdate', },
  oe                    => { name => t8('Orders'),                  description => t8('Orders and Quotations, Sales and Purchase'), keep => [ qw(id customer_id vendor_id) ], transdate => 'transdate', },
  delivery_orders       => { name => t8('Delivery Orders'),         description => t8('Delivery Orders'),                           keep => [ qw(id customer_id vendor_id) ], transdate => 'transdate', },
  gl                    => { name => t8('General Ledger'),          description => t8('General Ledger Entries'),                    keep => [ qw(id) ],                       transdate => 'transdate', },
  invoice               => { name => t8('Invoice Positions'),       description => t8('Positions for all Invoices'),                keep => [ qw(parts_id) ], tables => [ trans_id => "ar.id", "ap.id" ] },
  orderitems            => { name => t8('OrderItems'),              description => t8('Positions for all Orders'),                  keep => [ qw(parts_id) ], tables => [ trans_id => "oe.id" ] },
  delivery_order_items  => { name => t8('Delivery Order Items'),    description => t8('Positions for all Delivery Orders'),                      keep => [ qw(parts_id) ], tables => [ delivery_order_id => "delivery_orders.id" ] },
  acc_trans             => { name => t8('Transactions'),            description => t8('All general ledger entries'),                keep => [ qw(chart_id) ], tables => [ trans_id => "ar.id", "ap.id", "oe.id", "delivery_orders.id", "gl.id" ] },
  chart                 => { name => t8('Charts'),                  description => t8('Chart of Accounts'),                                                   tables => [ id => "acc_trans.chart_id" ] },
  customer              => { name => t8('Customers'),               description => t8('Customer Master Data'),                                                tables => [ id => "ar.customer_id", "ap.customer_id", "oe.customer_id", "delivery_orders.customer_id" ] },
  vendor                => { name => t8('Vendors'),                 description => t8('Vendor Master Data'),                                                  tables => [ id => "ar.vendor_id",   "ap.vendor_id",   "oe.vendor_id",   "delivery_orders.vendor_id" ] },
  parts                 => { name => t8('Parts'),                   description => t8('Parts, Services, and Assemblies'),                                     tables => [ id => "invoice.parts_id", "orderitems.parts_id", "delivery_order_items.parts_id" ] },
);

# rows in this listing are tiers.
# tables may depend on ids in a tier above them
my @export_table_order = qw(
  ar ap gl oe delivery_orders
  invoice orderitems delivery_order_items
  customer vendor
  parts
  acc_trans
  chart
);

# needed because the standard dbh sets datestyle german and we don't want to mess with that
my $date_format = 'DD.MM.YYYY';

# callbacks that produce the xml spec for these column types
my %column_types = (
  'Rose::DB::Object::Metadata::Column::Integer'   => sub { $_[0]->tag('Numeric') },  # see Caveats for integer issues
  'Rose::DB::Object::Metadata::Column::BigInt'    => sub { $_[0]->tag('Numeric') },  # see Caveats for integer issues
  'Rose::DB::Object::Metadata::Column::Text'      => sub { $_[0]->tag('AlphaNumeric') },
  'Rose::DB::Object::Metadata::Column::Varchar'   => sub { $_[0]->tag('AlphaNumeric') },
  'Rose::DB::Object::Metadata::Column::Character' => sub { $_[0]->tag('AlphaNumeric') },
  'Rose::DB::Object::Metadata::Column::Numeric'   => sub { $_[0]->tag('Numeric', sub { $_[0]->tag('Accuracy', 5) }) },
  'Rose::DB::Object::Metadata::Column::Date'      => sub { $_[0]->tag('Date', sub { $_[0]->tag('Format', $date_format) }) },
  'Rose::DB::Object::Metadata::Column::Timestamp' => sub { $_[0]->tag('Date', sub { $_[0]->tag('Format', $date_format) }) },
  'Rose::DB::Object::Metadata::Column::Float'     => sub { $_[0]->tag('Numeric') },
  'Rose::DB::Object::Metadata::Column::Boolean'   => sub { $_[0]
    ->tag('AlphaNumeric')
    ->tag('Map', sub { $_[0]
      ->tag('From', 1)
      ->tag('To', t8('true'))
    })
    ->tag('Map', sub { $_[0]
      ->tag('From', 0)
      ->tag('To', t8('false'))
    })
    ->tag('Map', sub { $_[0]
      ->tag('From', '')
      ->tag('To', t8('false'))
    })
  },
);

sub generate_export {
  my ($self) = @_;

  # verify data
  $self->from && 'DateTime' eq ref $self->from or die 'need from date';
  $self->to   && 'DateTime' eq ref $self->to   or die 'need to date';
  $self->from <= $self->to                     or die 'from date must be earlier or equal than to date';
  $self->tables && @{ $self->tables }          or die 'need tables';
  for (@{ $self->tables }) {
    next if $known_tables{$_};
    die "unknown table '$_'";
  }

  # get data from those tables and save to csv
  # for that we need to build queries that fetch all the columns
  for ($self->sorted_tables) {
    $self->do_csv_export($_);
  }

  # write xml file
  $self->do_xml_file;

  # add dtd
  $self->files->{'gdpdu-01-08-2002.dtd'} = File::Spec->catfile('users', 'gdpdu-01-08-2002.dtd');

  # make zip
  my ($fh, $zipfile) = File::Temp::tempfile();
  my $zip            = Archive::Zip->new;

  while (my ($name, $file) = each %{ $self->files }) {
    $zip->addFile($file, $name);
  }

  $zip->writeToFileHandle($fh) == Archive::Zip::AZ_OK() or die 'error writing zip file';
  close($fh);

  return $zipfile;
}

sub do_xml_file {
  my ($self) = @_;

  my ($fh, $filename) = File::Temp::tempfile();
  binmode($fh, ':utf8');

  $self->files->{'INDEX.XML'} = $filename;
  push @{ $self->tempfiles }, $filename;

  my $writer = XML::Writer->new(
    OUTPUT      => $fh,
    ENCODING    => 'UTF-8',
  );

  $self->writer($writer);
  $self->writer->xmlDecl('UTF-8');
  $self->writer->doctype('DataSet', undef, "gdpdu-01-08-2002.dtd");
  $self->tag('DataSet', sub { $self
    ->tag('Version', '1.0')
    ->tag('DataSupplier', sub { $self
      ->tag('Name', $self->client_name)
      ->tag('Location', $self->client_location)
      ->tag('Comment', $self->make_comment)
    })
    ->tag('Media', sub { $self
      ->tag('Name', t8('DataSet #1', 1));
      for (reverse $self->sorted_tables) { $self  # see CAVEATS for table order
        ->table($_)
      }
    })
  });
  close($fh);
}

sub table {
  my ($self, $table) = @_;
  my $writer = $self->writer;

  $self->tag('Table', sub { $self
    ->tag('URL', "$table.csv")
    ->tag('Name', $known_tables{$table}{name})
    ->tag('Description', $known_tables{$table}{description})
    ->tag('Validity', sub { $self
      ->tag('Range', sub { $self
        ->tag('From', $self->from->to_kivitendo(dateformat => 'dd.mm.yyyy'))
        ->tag('To',   $self->to->to_kivitendo(dateformat => 'dd.mm.yyyy'))
      })
      ->tag('Format', $date_format)
    })
    ->tag('UTF8')
    ->tag('DecimalSymbol', '.')
    ->tag('DigitGroupingSymbol', '|')     # see CAVEATS in documentation
    ->tag('VariableLength', sub { $self
      ->tag('ColumnDelimiter', ',')       # see CAVEATS for missing RecordDelimiter
      ->tag('TextEncapsulator', '"')
      ->columns($table)
      ->foreign_keys($table)
    })
  });
}

sub _table_columns {
  my ($table) = @_;
  my $package = SL::DB::Helper::Mappings::get_package_for_table($table);

  # PrimaryKeys must come before regular columns, so partition first
  partition_by { 1 * $_->is_primary_key_member } $package->meta->columns;
}

sub columns {
  my ($self, $table) = @_;

  my %cols_by_primary_key = _table_columns($table);

  for my $column (@{ $cols_by_primary_key{1} }) {
    my $type = $column_types{ ref $column };

    die "unknown col type @{[ ref $column ]}" unless $type;

    $self->tag('VariablePrimaryKey', sub { $self
      ->tag('Name', $column->name);
      $type->($self);
    })
  }

  for my $column (@{ $cols_by_primary_key{0} }) {
    my $type = $column_types{ ref $column };

    die "unknown col type @{[ ref $column]}" unless $type;

    $self->tag('VariableColumn', sub { $self
      ->tag('Name', $column->name);
      $type->($self);
    })
  }

  $self;
}

sub foreign_keys {
  my ($self, $table) = @_;
  my $package = SL::DB::Helper::Mappings::get_package_for_table($table);

  my %requested = map { $_ => 1 } @{ $self->tables };

  for my $rel ($package->meta->foreign_keys) {
    next unless $requested{ $rel->class->meta->table };

    # ok, now extract the columns used as foreign key
    my %key_columns = $rel->key_columns;

    if (1 != keys %key_columns) {
      die "multi keys? we don't support this currently. fix it please";
    }

    if ($table eq $rel->class->meta->table) {
      # self referential foreign keys are a PITA to export correctly. skip!
      next;
    }

    $self->tag('ForeignKey', sub {
      $_[0]->tag('Name', $_) for keys %key_columns;
      $_[0]->tag('References', $rel->class->meta->table);
   });
  }
}

sub do_csv_export {
  my ($self, $table) = @_;

  my $csv = Text::CSV_XS->new({ binary => 1, eol => "\r\n", sep_char => ",", quote_char => '"' });

  my ($fh, $filename) = File::Temp::tempfile();
  binmode($fh, ':utf8');

  $self->files->{"$table.csv"} = $filename;
  push @{ $self->tempfiles }, $filename;

  # in the right order (primary keys first)
  my %cols_by_primary_key = _table_columns($table);
  my @columns = (@{ $cols_by_primary_key{1} }, @{ $cols_by_primary_key{0} });
  my %col_index = do { my $i = 0; map {; "$_" => $i++ } @columns };

  # and normalize date stuff
  my @select_tokens = map { (ref $_) =~ /Time/ ? $_->name . '::date' : $_->name } @columns;

  my @where_tokens;
  my @values;
  if ($known_tables{$table}{transdate}) {
    if ($self->from) {
      push @where_tokens, "$known_tables{$table}{transdate} >= ?";
      push @values, $self->from;
    }
    if ($self->to) {
      push @where_tokens, "$known_tables{$table}{transdate} <= ?";
      push @values, $self->to;
    }
  }
  if ($known_tables{$table}{tables}) {
    my ($col, @col_specs) = @{ $known_tables{$table}{tables} };
    my %ids;
    for (@col_specs) {
      my ($ftable, $fkey) = split /\./, $_;
      if (!exists $self->export_ids->{$ftable}{$fkey}) {
         # check if we forgot to keep it
         if (!grep { $_ eq $fkey } @{ $known_tables{$ftable}{keep} || [] }) {
           die "unknown table spec '$_' for table $table, did you forget to keep $fkey in $ftable?"
         } else {
           # hmm, most likely just an empty set.
           $self->export_ids->{$ftable}{$fkey} = {};
         }
      }
      $ids{$_}++ for keys %{ $self->export_ids->{$ftable}{$fkey} };
    }
    if (keys %ids) {
      push @where_tokens, "$col IN (@{[ join ',', ('?') x keys %ids ]})";
      push @values, keys %ids;
    } else {
      push @where_tokens, '1=0';
    }
  }

  my $where_clause = @where_tokens ? 'WHERE ' . join ' AND ', @where_tokens : '';

  my $query = "SELECT " . join(', ', @select_tokens) . " FROM $table $where_clause";

  my $sth = $::form->get_standard_dbh->prepare($query);
  $sth->execute(@values) or die "error executing query $query: " . $sth->errstr;

  while (my $row = $sth->fetch) {
    for my $keep_col (@{ $known_tables{$table}{keep} || [] }) {
      next if !$row->[$col_index{$keep_col}];
      $self->export_ids->{$table}{$keep_col} ||= {};
      $self->export_ids->{$table}{$keep_col}{$row->[$col_index{$keep_col}]}++;
    }
    s/\r\n/ /g for @$row; # see CAVEATS

    $csv->print($fh, $row) or $csv->error_diag;
  }
  $sth->finish();
}

sub tag {
  my ($self, $tag, $content) = @_;

  $self->writer->startTag($tag);
  if ('CODE' eq ref $content) {
    $content->($self);
  } else {
    $self->writer->characters($content);
  }
  $self->writer->endTag;
  return $self;
}

sub make_comment {
  my $gdpdu_version = API_VERSION();
  my $kivi_version  = $::form->read_version;
  my $person        = $::myconfig{name};
  my $contact       = join ', ',
    (t8("Email") . ": $::myconfig{email}" ) x!! $::myconfig{email},
    (t8("Tel")   . ": $::myconfig{tel}" )   x!! $::myconfig{tel},
    (t8("Fax")   . ": $::myconfig{fax}" )   x!! $::myconfig{fax};

  t8('DataSet for GDPdU version #1. Created with kivitendo #2 by #3 (#4)',
    $gdpdu_version, $kivi_version, $person, $contact
  );
}

sub client_name {
  $_[0]->company
}

sub client_location {
  $_[0]->location
}

sub sorted_tables {
  my ($self) = @_;

  my %given = map { $_ => 1 } @{ $self->tables };

  grep { $given{$_} } @export_table_order;
}

sub all_tables {
  my ($self, $yesno) = @_;

  $self->tables(\@export_table_order) if $yesno;
}

sub init_files { +{} }
sub init_export_ids { +{} }
sub init_tempfiles { [] }

sub API_VERSION {
  DateTime->new(year => 2002, month => 8, day => 14)->to_kivitendo;
}

sub DESTROY {
  unlink $_ for @{ $_[0]->tempfiles || [] };
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::GDPDU - IDEA export generator

=head1 FUNCTIONS

=over 4

=item C<new PARAMS>

Create new export object. C<PARAMS> may contain:

=over 4

=item company

The name of the company, needed for the supplier header

=item location

Location of the company, needed for the suupplier header

=item from

=item to

Will only include records in the specified date range. Data pulled from other
tables will be culled to match what is needed for these records.

=item tables

A list of tables to be exported.

=item all_tables

Alternative to C<tables>, enables all known tables.

=back

=item C<generate_export>

Do the work. Will return an absolut path to a temp file where all export files
are zipped together.

=back

=head1 CAVEATS

=over 4

=item *

Date format is shit. The official docs state that only C<YY>, C<YYYY>, C<MM>,
and C<DD> are supported, timestamps do not exist.

=item *

Number parsing seems to be fragile. Official docs state that behaviour for too
low C<Accuracy> settings is undefined. Accuracy of 0 is not taken to mean
Integer but instead generates a warning for redudancy.

There is no dedicated integer type.

=item *

Currently C<ar> and C<ap> have a foreign key to themself with the name
C<storno_id>. If this foreign key is present in the C<INDEX.XML> then the
storno records have to be too. Since this is extremely awkward to code and
confusing for the examiner as to why there are records outside of the time
range, this export skips all self-referential foreign keys.

=item *

Documentation for foreign keys is extremely weird. Instead of giving column
maps it assumes that foreign keys map to the primary keys given for the target
table, and in that order. Foreign keys to keys that are not primary seems to be
impossible. Changing type is also not allowed (which actually makes sense).
Hopefully there are no bugs there.

=item *

It's currently disallowed to export the whole dataset. It's not clear if this
is wanted.

=item *

It is not possible to set an empty C<DigiGroupingSymbol> since then the import
will just work with the default. This was asked in their forum, and the
response actually was:

  Einfache Lösung: Definieren Sie das Tausendertrennzeichen als Komma, auch
  wenn es nicht verwendet wird. Sollten Sie das Komma bereits als Feldtrenner
  verwenden, so wählen Sie als Tausendertrennzeichen eine Alternative wie das
  Pipe-Symbol |.

L<http://www.gdpdu-portal.com/forum/index.php?mode=thread&id=1392>

=item *

It is not possible to define a C<RecordDelimiter> with XML entities. &#x0A;
generates the error message:

  C<RecordDelimiter>-Wert (&#x0A;) sollte immer aus ein oder zwei Zeichen
  bestehen.

Instead we just use the implicit default RecordDelimiter CRLF.

=item *

Not confirmed yet:

Foreign keys seem only to work with previously defined tables (which would be
utterly insane).

=item *

The CSV import library used in IDEA is not able to parse newlines (or more
exactly RecordDelimiter) in data. So this export substites all of these with
spaces.

=back

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
