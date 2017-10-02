package SL::GoBD;

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
use SL::Version;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(from to writer company location) ],
  'scalar --get_set_init' => [ qw(files tempfiles export_ids tables csv_headers) ],
);

# in this we find:
# key:         table name
# name:        short name, translated
# description: long description, translated
# columns:     list of columns to export. export all columns if not present
# primary_key: override primary key
my %known_tables = (
  chart    => { name => t8('Charts'),    description => t8('Chart of Accounts'),    primary_key => 'accno', columns => [ qw(id accno description) ],     },
  customer => { name => t8('Customers'), description => t8('Customer Master Data'), columns => [ qw(id customernumber name department_1 department_2 street zipcode city country contact phone fax email notes taxnumber obsolete ustid) ] },
  vendor   => { name => t8('Vendors'),   description => t8('Vendor Master Data'),   columns => [ qw(id vendornumber name department_1 department_2 street zipcode city country contact phone fax email notes taxnumber obsolete ustid) ] },
);

my %column_titles = (
   chart => {
     id             => t8('ID'),
     accno          => t8('Account Number'),
     description    => t8('Description'),
   },
   customer_vendor => {
     id             => t8('ID (lit)'),
     name           => t8('Name'),
     department_1   => t8('Department 1'),
     department_2   => t8('Department 2'),
     street         => t8('Street'),
     zipcode        => t8('Zipcode'),
     city           => t8('City'),
     country        => t8('Country'),
     contact        => t8('Contact'),
     phone          => t8('Phone'),
     fax            => t8('Fax'),
     email          => t8('E-mail'),
     notes          => t8('Notes'),
     customernumber => t8('Customer Number'),
     vendornumber   => t8('Vendor Number'),
     taxnumber      => t8('Tax Number'),
     obsolete       => t8('Obsolete'),
     ustid          => t8('Tax ID number'),
   },
);
$column_titles{$_} = $column_titles{customer_vendor} for qw(customer vendor);

my %datev_column_defs = (
  trans_id          => { type => 'Rose::DB::Object::Metadata::Column::Integer', text => t8('ID'), },
  amount            => { type => 'Rose::DB::Object::Metadata::Column::Numeric', text => t8('Amount'), },
  credit_accname    => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Credit Account Name'), },
  credit_accno      => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Credit Account'), },
  credit_amount     => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Credit Amount'), },
  credit_tax        => { type => 'Rose::DB::Object::Metadata::Column::Numeric', text => t8('Credit Tax (lit)'), },
  debit_accname     => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Debit Account Name'), },
  debit_accno       => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Debit Account'), },
  debit_amount      => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Debit Amount'), },
  debit_tax         => { type => 'Rose::DB::Object::Metadata::Column::Numeric', text => t8('Debit Tax (lit)'), },
  invnumber         => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Reference'), },
  name              => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Name'), },
  notes             => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Notes'), },
  tax               => { type => 'Rose::DB::Object::Metadata::Column::Numeric', text => t8('Tax'), },
  taxdescription    => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('tax_taxdescription'), },
  taxkey            => { type => 'Rose::DB::Object::Metadata::Column::Integer', text => t8('Taxkey'), },
  tax_accname       => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Tax Account Name'), },
  tax_accno         => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Tax Account'), },
  transdate         => { type => 'Rose::DB::Object::Metadata::Column::Date',    text => t8('Transdate'), },
  vcnumber          => { type => 'Rose::DB::Object::Metadata::Column::Text',    text => t8('Customer/Vendor Number'), },
  customer_id       => { type => 'Rose::DB::Object::Metadata::Column::Integer', text => t8('Customer (database ID)'), },
  vendor_id         => { type => 'Rose::DB::Object::Metadata::Column::Integer', text => t8('Vendor (database ID)'), },
  itime             => { type => 'Rose::DB::Object::Metadata::Column::Date',    text => t8('Create Date'), },
  gldate            => { type => 'Rose::DB::Object::Metadata::Column::Date',    text => t8('Gldate'), },
);

my @datev_columns = qw(
  trans_id
  customer_id vendor_id
  name           vcnumber
  transdate    invnumber      amount
  debit_accno  debit_accname debit_amount debit_tax
  credit_accno credit_accname credit_amount credit_tax
  taxdescription tax
  tax_accno    tax_accname    taxkey
  notes itime gldate
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
my $number_format = '1000.00';

my $myconfig = { numberformat => $number_format };

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
    ->tag('Range', sub { $self
      ->tag('From', $self->csv_headers ? 2 : 1)
    })
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
      ->tag('Name', $column_titles{$table}{$column->name});
      $type->($self);
    })
  }

  for my $column (@{ $cols_by_primary_key{0} }) {
    my $type = $column_types{ ref $column };

    die "unknown col type @{[ ref $column]}" unless $type;

    $self->tag('VariableColumn', sub { $self
      ->tag('Name', $column_titles{$table}{$column->name});
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
      $_[0]->tag('Name',  $column_titles{$table}{$_}) for keys %key_columns;
      $_[0]->tag('References', $rel->class->meta->table);
   });
  }
}

sub do_datev_xml_table {
  my ($self) = @_;
  my $writer = $self->writer;

  $self->tag('Table', sub { $self
    ->tag('URL', "transactions.csv")
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
    ->tag('Range', sub { $self
      ->tag('From', $self->csv_headers ? 2 : 1)
    })
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

  for my $column (@{ $cols_by_primary_key{1} }) {
    my $type = $column_types{ $datev_column_defs{$column}{type} };

    die "unknown col type @{[ $column ]}" unless $type;

    $self->tag('VariablePrimaryKey', sub { $self
      ->tag('Name', $datev_column_defs{$column}{text});
      $type->($self);
    })
  }

  for my $column (@{ $cols_by_primary_key{0} }) {
    my $type = $column_types{ $datev_column_defs{$column}{type} };

    die "unknown col type @{[ ref $column]}" unless $type;

    $self->tag('VariableColumn', sub { $self
      ->tag('Name', $datev_column_defs{$column}{text});
      $type->($self);
    })
  }

  $self;
}

sub datev_foreign_keys {
  my ($self) = @_;
  # hard code weeee
  $self->tag('ForeignKey', sub { $_[0]
    ->tag('Name', $datev_column_defs{customer_id}{text})
    ->tag('References', 'customer')
  });
  $self->tag('ForeignKey', sub { $_[0]
    ->tag('Name', $datev_column_defs{vendor_id}{text})
    ->tag('References', 'vendor')
  });
  $self->tag('ForeignKey', sub { $_[0]
    ->tag('Name', $datev_column_defs{$_}{text})
    ->tag('References', 'chart')
  }) for qw(debit_accno credit_accno tax_accno);
}

sub do_datev_csv_export {
  my ($self) = @_;

  my $datev = SL::DATEV->new(from => $self->from, to => $self->to);

  $datev->generate_datev_data(from_to => $datev->fromto);

  if ($datev->errors) {
    die [ $datev->errors ];
  }

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

  if ($self->csv_headers) {
    $csv->print($fh, [ map { _normalize_cell($datev_column_defs{$_}{text}) } @datev_columns ]);
  }

  for my $transaction (@transactions) {
    my $is_payment     = any { $_->{link} =~ m{A[PR]_paid} } @{ $transaction };

    my ($soll, $haben) = map { $transaction->[$_] } ($transaction->[0]->{amount} > 0 ? (1, 0) : (0, 1));
    my $tax            = defined($soll->{tax_accno}) ? $soll : defined($haben->{tax_accno}) ? $haben : {};
    my $amount         = defined($soll->{net_amount}) ? $soll : $haben;
    $haben->{notes}    = ($haben->{memo} || $soll->{memo}) if $haben->{memo} || $soll->{memo};
    $haben->{notes}  //= '';
    $haben->{notes}    =  SL::HTML::Util->strip($haben->{notes});

    my $tax_amount = defined $amount->{net_amount} ? abs($amount->{amount}) - abs($amount->{net_amount}) : 0;

    $tax = {} if abs($tax_amount) < 0.001;

    my %row            = (
      amount           => $::form->format_amount($myconfig, abs($amount->{amount}),5),
      debit_accno      => $soll->{accno},
      debit_accname    => $soll->{accname},
      debit_amount     => $::form->format_amount($myconfig, abs(-$soll->{amount}),5),
      debit_tax        => $soll->{tax_accno} ? $::form->format_amount($myconfig, $tax_amount, 5) : 0,
      credit_accno     => $haben->{accno},
      credit_accname   => $haben->{accname},
      credit_amount    => $::form->format_amount($myconfig, abs($haben->{amount}),5),,
      credit_tax       => $haben->{tax_accno} ? $::form->format_amount($myconfig, $tax_amount, 5) : 0,
      tax              => $::form->format_amount($myconfig, $tax_amount, 5),
      notes            => $haben->{notes},
      (map { ($_ => $tax->{$_})                    } qw(taxkey tax_accname tax_accno taxdescription)),
      (map { ($_ => ($haben->{$_} // $soll->{$_})) } qw(trans_id invnumber name vcnumber transdate gldate itime customer_id vendor_id)),
    );

#     if ($row{debit_amount} + $row{debit_tax} - ($row{credit_amount} + $row{credit_tax}) > 0.005) {
#       $::lxdebug->dump(0,  "broken taxes", [ $transaction, \%row,  $row{debit_amount} + $row{debit_tax}, $row{credit_amount} + $row{credit_tax} ]);
#     }

    _normalize_cell($_) for values %row; # see CAVEATS

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

  if ($self->csv_headers) {
    $csv->print($fh, [ map { _normalize_cell($column_titles{$table}{$_->name}) } @columns ]) or die $csv->error_diag;
  }

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
  $sth->execute(@values) or $::form->dberror($query);

  while (my $row = $sth->fetch) {
    for my $keep_col (@{ $known_tables{$table}{keep} || [] }) {
      next if !$row->[$col_index{$keep_col}];
      $self->export_ids->{$table}{$keep_col} ||= {};
      $self->export_ids->{$table}{$keep_col}{$row->[$col_index{$keep_col}]}++;
    }
    _normalize_cell($_) for @$row; # see CAVEATS

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
  my $gobd_version  = API_VERSION();
  my $kivi_version  = SL::Version->get_version;
  my $person        = $::myconfig{name};
  my $contact       = join ', ',
    (t8("Email") . ": $::myconfig{email}" ) x!! $::myconfig{email},
    (t8("Tel")   . ": $::myconfig{tel}" )   x!! $::myconfig{tel},
    (t8("Fax")   . ": $::myconfig{fax}" )   x!! $::myconfig{fax};

  t8('DataSet for GoBD version #1. Created with kivitendo #2 by #3 (#4)',
    $gobd_version, $kivi_version, $person, $contact
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

sub _normalize_cell {
  $_[0] =~ s/\r\n/ /g;
  $_[0] =~ s/,/;/g;
  $_[0] =~ s/"/'/g;
  $_[0] =~ s/!/./g;
  $_[0]
}

sub init_files { +{} }
sub init_export_ids { +{} }
sub init_tempfiles { [] }
sub init_tables { [ grep { $known_tables{$_} } @export_table_order ] }
sub init_csv_headers { 1 }

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

SL::GoBD - IDEA export generator

=head1 FUNCTIONS

=over 4

=item C<new PARAMS>

Create new export object. C<PARAMS> may contain:

=over 4

=item company

The name of the company, needed for the supplier header

=item location

Location of the company, needed for the supplier header

=item from

=item to

Will only include records in the specified date range. Data pulled from other
tables will be culled to match what is needed for these records.

=item csv_headers

Optional. If set, will include a header line in the exported CSV files. Default true.

=item tables

Ooptional list of tables to be exported. Defaults to all tables.

=item all_tables

Optional alternative to C<tables>, forces all known tables.

=back

=item C<generate_export>

Do the work. Will return an absolute path to a temp file where all export files
are zipped together.

=back

=head1 CAVEATS

Sigh. There are a lot of issues with the IDEA software that were found out by
trial and error.

=head2 Problems in the Specification

=over 4

=item *

The specced date format is capable of only C<YY>, C<YYYY>, C<MM>,
and C<DD>. There are no timestamps or timezones.

=item *

Numbers have the same issue. There is not dedicated integer type, and hinting
at an integer type by setting accuracy to 0 generates a warning for redundant
accuracy.

Also the number parsing is documented to be fragile. Official docs state that
behaviour for too low C<Accuracy> settings is undefined.

=item *

Foreign key definition is broken. Instead of giving column maps it assumes that
foreign keys map to the primary keys given for the target table, and in that
order. Also the target table must be known in full before defining a foreign key.

As a consequence any additional keys apart from primary keys are not possible.
Self-referencing tables are also not possible.

=item *

The spec does not support splitting data sets into smaller chunks. For data
sets that exceed 700MB the spec helpfully suggests: "Use a bigger medium, such
as a DVD".

=item *

It is not possible to set an empty C<DigitGroupingSymbol> since then the import
will just work with the default. This was asked in their forum, and the
response actually was to use a bogus grouping symbol that is not used:

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

=back

=head2 Bugs in the IDEA software

=over 4

=item *

The CSV import library used in IDEA is not able to parse newlines (or more
exactly RecordDelimiter) in data. So this export substites all of these with
spaces.

=item *

Neither it is able to parse escaped C<ColumnDelimiter> in data. It just splits
on that symbol no matter what surrounds or preceeds it.

=item *

Oh and of course C<TextEncapsulator> is also not allowed in data. It's just
stripped at the beginning and end of data.

=item *

And the character "!" is used internally as a warning signal and must not be
present in the data as well.

=item *

C<VariableLength> data is truncated on import to 512 bytes (Note: it said
characters, but since they are mutilating data into a single byte encoding
anyway, they most likely meant bytes). The auditor recommends splitting into
multiple columns.

=item *

Despite the standard specifying UTF-8 as a valid encoding the IDEA software
will just downgrade everything to latin1.

=back

=head2 Problems outside of the software

=over 4

=item *

The law states that "all business related data" should be made available. In
practice there's no definition for what makes data "business related", and
different auditors seems to want different data.

Currently we export most of the transactional data with supplementing
customers, vendors and chart of accounts.

=item *

While the standard explicitely state to provide data normalized, in practice
autditors aren't trained database operators and can not create complex vies on
normalized data on their own. The reason this works for other software is, that
DATEV and SAP seem to have written import plugins for their internal formats in
the IDEA software.

So what is really exported is not unlike a DATEV export. Each transaction gets
splitted into chunks of 2 positions (3 with tax on one side). Those get
denormalized into a single data row with credfit/debit/tax fields. The charts
get denormalized into it as well, in addition to their account number serving
as a foreign key.

Customers and vendors get denormalized into this as well, but are linked by ids
to their tables. And the reason for this is...

=item *

Some auditors do not have a full license of the IDEA software, and
can't do table joins.

=back

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
