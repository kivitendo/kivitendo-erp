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
use List::MoreUtils qw(any);
use List::UtilsBy qw(partition_by sort_by);

use SL::DB::Helper::ALL; # since we work on meta data, we need everything
use SL::DB::Helper::Mappings;
use SL::Locale::String qw(t8);

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(from to writer company location) ],
  'scalar --get_set_init' => [ qw(files tempfiles export_ids tables) ],
);

# in this we find:
# key:         table name
# name:        short name, translated
# description: long description, translated
# transdate:   column used to filter from/to, empty if table is filtered otherwise
# keep:        arrayref of columns that should be saved for further referencing
# tables:      arrayref with one column and one or many table.column references that were kept earlier
my %known_tables = (
  chart    => { name => t8('Charts'),    description => t8('Chart of Accounts'),    primary_key => 'accno', columns => [ qw(id accno description) ],     },
  customer => { name => t8('Customers'), description => t8('Customer Master Data'), columns => [ qw(id name department_1 department_2 street zipcode city country contact phone fax email notes customernumber taxnumber obsolete ustid) ] },
  vendor   => { name => t8('Vendors'),   description => t8('Vendor Master Data'),   columns => [ qw(id name department_1 department_2 street zipcode city country contact phone fax email notes customernumber taxnumber obsolete ustid) ] },
);

my %datev_column_defs = (
  acc_trans_id      => { type => 'Rose::DB::Object::Metadata::Column::Integer', text => t8('ID'), primary_key => 1 },
  amount            => { type => 'Rose::DB::Object::Metadata::Column::Numeric', text => t8('Amount'), },
  credit_accname    => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Credit Account Name'), },
  credit_accno      => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Credit Account'), },
  debit_accname     => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Debit Account Name'), },
  debit_accno       => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Debit Account'), },
  invnumber         => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Reference'), },
  name              => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Name'), },
  notes             => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Notes'), },
  tax               => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Tax'), },
  taxdescription    => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('tax_taxdescription'), },
  taxkey            => { type => 'Rose::DB::Object::Metadata::Column::Integer', text => t8('Taxkey'), },
  tax_accname       => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Tax Account Name'), },
  tax_accno         => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Tax Account'), },
  transdate         => { type => 'Rose::DB::Object::Metadata::Column::Date',    text => t8('Invoice Date'), },
  vcnumber          => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Customer/Vendor Number'), },
  customer_id       => { type => 'Rose::DB::Object::Metadata::Column::Integer', text => t8('Customer (database ID)'), },
  vendor_id         => { type => 'Rose::DB::Object::Metadata::Column::Integer', text => t8('Vendor (database ID)'), },
  itime             => { type => 'Rose::DB::Object::Metadata::Column::Date',    text => t8('Create Date'), },
);

my @datev_columns = qw(
  acc_trans_id
  customer_id vendor_id
  name           vcnumber
  transdate    invnumber      amount
  debit_accno  debit_accname
  credit_accno credit_accname
  taxdescription tax
  tax_accno    tax_accname    taxkey
  notes itime
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

  $self->do_datev_csv_export;

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
      $self->do_datev_xml_table;
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

  my %white_list;
  my $use_white_list = 0;
  if ($known_tables{$table}{columns}) {
    $use_white_list = 1;
    $white_list{$_} = 1 for @{ $known_tables{$table}{columns} || [] };
  }

  # PrimaryKeys must come before regular columns, so partition first
  partition_by {
    $known_tables{$table}{primary_key}
      ? 1 * ($_ eq $known_tables{$table}{primary_key})
      : 1 * $_->is_primary_key_member
  } grep {
    $use_white_list ? $white_list{$_->name} : 1
  } $package->meta->columns;
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

sub do_datev_xml_table {
  my ($self) = @_;
  my $writer = $self->writer;

  $self->tag('Table', sub { $self
    ->tag('URL', "transaction.csv")
    ->tag('Name', t8('Transactions'))
    ->tag('Description', t8('Transactions'))
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
      ->datev_columns
      ->datev_foreign_keys
    })
  });
}

sub datev_columns {
  my ($self, $table) = @_;

  my %cols_by_primary_key = partition_by { 1 * $datev_column_defs{$_}{primary_key} } @datev_columns;
  $::lxdebug->dump(0,  "cols", \%cols_by_primary_key);

  for my $column (@{ $cols_by_primary_key{1} }) {
    my $type = $column_types{ $datev_column_defs{$column}{type} };

    die "unknown col type @{[ $column ]}" unless $type;

    $self->tag('VariablePrimaryKey', sub { $self
      ->tag('Name', $column);
      $type->($self);
    })
  }

  for my $column (@{ $cols_by_primary_key{0} }) {
    my $type = $column_types{ $datev_column_defs{$column}{type} };

    die "unknown col type @{[ ref $column]}" unless $type;

    $self->tag('VariableColumn', sub { $self
      ->tag('Name', $column);
      $type->($self);
    })
  }

  $self;
}

sub datev_foreign_keys {
  my ($self) = @_;
  # hard code weeee
  $self->tag('ForeignKey', sub { $_[0]
    ->tag('Name', 'customer_id')
    ->tag('References', 'customer')
  });
  $self->tag('ForeignKey', sub { $_[0]
    ->tag('Name', 'vendor_id')
    ->tag('References', 'vendor')
  });
  $self->tag('ForeignKey', sub { $_[0]
    ->tag('Name', $_)
    ->tag('References', 'chart')
  }) for qw(debit_accno credit_accno tax_accno);
}

sub do_datev_csv_export {
  my ($self) = @_;

  my $datev = SL::DATEV->new(from => $self->from, to => $self->to);

  $datev->_get_transactions(from_to => $datev->fromto);

  for my $transaction (@{ $datev->{DATEV} }) {
    for my $entry (@{ $transaction }) {
      $entry->{sortkey} = join '-', map { lc } (DateTime->from_kivitendo($entry->{transdate})->strftime('%Y%m%d'), $entry->{name}, $entry->{reference});
    }
  }

  my @transactions = sort_by { $_->[0]->{sortkey} } @{ $datev->{DATEV} };

  my $csv = Text::CSV_XS->new({ binary => 1, eol => "\r\n", sep_char => ",", quote_char => '"' });

  my ($fh, $filename) = File::Temp::tempfile();
  binmode($fh, ':utf8');

  $self->files->{"transactions.csv"} = $filename;
  push @{ $self->tempfiles }, $filename;

  for my $transaction (@transactions) {
    my $is_payment     = any { $_->{link} =~ m{A[PR]_paid} } @{ $transaction };

    my ($soll, $haben) = map { $transaction->[$_] } ($transaction->[0]->{amount} > 0 ? (1, 0) : (0, 1));
    my $tax            = defined($soll->{tax_accno})  ? $soll : $haben;
    my $amount         = defined($soll->{net_amount}) ? $soll : $haben;
    $haben->{notes}    = ($haben->{memo} || $soll->{memo}) if $haben->{memo} || $soll->{memo};
    $haben->{notes}  //= '';
    $haben->{notes}    =  SL::HTML::Util->strip($haben->{notes});
    $haben->{notes}    =~ s{\r}{}g;
    $haben->{notes}    =~ s{\n+}{ }g;

    my %row            = (
      customer_id      => $soll->{customer_id} || $haben->{customer_id},
      vendor_id        => $soll->{vendor_id} || $haben->{vendor_id},
      amount           => abs($amount->{amount}),
      debit_accno      => $soll->{accno},
      debit_accname    => $soll->{accname},
      credit_accno     => $haben->{accno},
      credit_accname   => $haben->{accname},
      tax              => defined $amount->{net_amount} ? abs($amount->{amount}) - abs($amount->{net_amount}) : 0,
      taxdescription   => defined($soll->{tax_accno}) ? $soll->{taxdescription} : $haben->{taxdescription},
      notes            => $haben->{notes},
      itime            => $soll->{itime},
      (map { ($_ => $tax->{$_})                    } qw(taxkey tax_accname tax_accno)),
      (map { ($_ => ($haben->{$_} // $soll->{$_})) } qw(acc_trans_id invnumber name vcnumber transdate)),
    );

    $csv->print($fh, [ map { $row{$_} } @datev_columns ]);
  }

  # and build xml spec for it
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
sub init_tables { [ grep { $known_tables{$_} } @export_table_order ] }

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
