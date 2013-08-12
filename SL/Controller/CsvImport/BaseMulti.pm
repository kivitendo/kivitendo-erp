package SL::Controller::CsvImport::BaseMulti;

use strict;

use List::MoreUtils qw(pairwise);

use SL::Helper::Csv;
use SL::DB::Customer;
use SL::DB::Language;
use SL::DB::PaymentTerm;
use SL::DB::Vendor;
use SL::DB::Contact;

use parent qw(SL::Controller::CsvImport::Base);

sub run {
  my ($self, %params) = @_;

  $self->test_run($params{test_run});

  $self->controller->track_progress(phase => 'parsing csv', progress => 0);

  my $profile = $self->profile;

  $self->csv(SL::Helper::Csv->new(file                    => $self->file->file_name,
                                  encoding                => $self->controller->profile->get('charset'),
                                  profile                 => $profile,
                                  ignore_unknown_columns  => 1,
                                  strict_profile          => 1,
                                  case_insensitive_header => 1,
                                  map { ( $_ => $self->controller->profile->get($_) ) } qw(sep_char escape_char quote_char),
                                 ));

  $self->controller->track_progress(progress => 10);

  my $old_numberformat      = $::myconfig{numberformat};
  $::myconfig{numberformat} = $self->controller->profile->get('numberformat');

  $self->csv->parse;

  $self->controller->track_progress(progress => 50);

  # bb: make sanity-check of it?
  #if ($self->csv->is_multiplexed != $self->is_multiplexed) {
  #  die "multiplex controller on simplex data or vice versa";
  #}

  $self->controller->errors([ $self->csv->errors ]) if $self->csv->errors;

  return if ( !$self->csv->header || $self->csv->errors );

  my $headers;
  my $i = 0;
  foreach my $header (@{ $self->csv->header }) {

    my $profile   = $self->csv->profile->[$i]->{profile};
    my $row_ident = $self->csv->profile->[$i]->{row_ident};

    my $h = { headers => [ grep { $profile->{$_} } @{ $header } ] };
    $h->{methods} = [ map { $profile->{$_} } @{ $h->{headers} } ];
    $h->{used}    = { map { ($_ => 1) }      @{ $h->{headers} } };

    $headers->{$row_ident} = $h;
    $i++;
  }

  $self->controller->headers($headers);

  my $raw_data_headers;
  my $info_headers;
  foreach my $p (@{ $self->csv->profile }) {
    $raw_data_headers->{ $p->{row_ident} } = { used => { }, headers => [ ] };
    $info_headers->{ $p->{row_ident} }     = { used => { }, headers => [ ] };
  }
  $self->controller->raw_data_headers($raw_data_headers);
  $self->controller->info_headers($info_headers);

  my @objects  = $self->csv->get_objects;
  $self->controller->track_progress(progress => 70);

  my @raw_data = @{ $self->csv->get_data };

  $self->controller->track_progress(progress => 80);

  $self->controller->data([ pairwise { { object => $a, raw_data => $b, errors => [], information => [], info_data => {} } } @objects, @raw_data ]);

  $self->controller->track_progress(progress => 90);

  $self->check_objects;
  if ( $self->controller->profile->get('duplicates', 'no_check') ne 'no_check' ) {
    $self->check_std_duplicates();
    $self->check_duplicates();
  }
  $self->fix_field_lengths;

  $self->controller->track_progress(progress => 100);

  $::myconfig{numberformat} = $old_numberformat;
}

sub add_columns {
  my ($self, $row_ident, @columns) = @_;

  my $h = $self->controller->headers->{$row_ident};

  foreach my $column (grep { !$h->{used}->{$_} } @columns) {
    $h->{used}->{$column} = 1;
    push @{ $h->{methods} }, $column;
    push @{ $h->{headers} }, $column;
  }
}

sub add_info_columns {
  my ($self, $row_ident, @columns) = @_;

  my $h = $self->controller->info_headers->{$row_ident};

  foreach my $column (grep { !$h->{used}->{ $_->{method} } } map { ref $_ eq 'HASH' ? $_ : { method => $_, header => $_ } } @columns) {
    $h->{used}->{ $column->{method} } = 1;
    push @{ $h->{methods} }, $column->{method};
    push @{ $h->{headers} }, $column->{header};
  }
}

sub add_raw_data_columns {
  my ($self, $row_ident, @columns) = @_;

  my $h = $self->controller->raw_data_headers->{$row_ident};

  foreach my $column (grep { !$h->{used}->{$_} } @columns) {
    $h->{used}->{$column} = 1;
    push @{ $h->{headers} }, $column;
  }
}

sub add_cvar_raw_data_columns {
  my ($self) = @_;

  map { $self->add_raw_data_columns($_) if exists $self->controller->data->[0]->{raw_data}->{$_} } @{ $self->cvar_columns };
}

sub init_profile {
  my ($self) = @_;

  my @profile;
  foreach my $class (@{ $self->class }) {
    eval "require " . $class;

    my %unwanted = map { ( $_ => 1 ) } (qw(itime mtime), map { $_->name } @{ $class->meta->primary_key_columns });
    my %prof;
    $prof{datatype} = '';
    for my $col ($class->meta->columns) {
      next if $unwanted{$col};

      my $name = $col->isa('Rose::DB::Object::Metadata::Column::Numeric')   ? "$col\_as_number"
          :      $col->isa('Rose::DB::Object::Metadata::Column::Date')      ? "$col\_as_date"
          :      $col->isa('Rose::DB::Object::Metadata::Column::Timestamp') ? "$col\_as_date"
          :                                                                   $col->name;

      $prof{$col} = $name;
    }

    $prof{ 'cvar_' . $_->name } = '' for @{ $self->all_cvar_configs };

    $class =~ m/^SL::DB::(.+)/;
    push @profile, {'profile' => \%prof, 'class' => $class, 'row_ident' => $1};
  }

  \@profile;
}

sub add_displayable_columns {
  my ($self, $row_ident, @columns) = @_;

  my $dis_cols = $self->controller->displayable_columns || {};

  my @cols       = @{ $dis_cols->{$row_ident} || [] };
  my %ex_col_map = map { $_->{name} => $_ } @cols;

  foreach my $column (@columns) {
    if ($ex_col_map{ $column->{name} }) {
      @{ $ex_col_map{ $column->{name} } }{ keys %{ $column } } = @{ $column }{ keys %{ $column } };
    } else {
      push @cols, $column;
    }
  }

  my $by_name_datatype_first = sub { 'datatype' eq $a->{name} ? -1 :
                                     'datatype' eq $b->{name} ?  1 :
                                     $a->{name} cmp $b->{name} };
  $dis_cols->{$row_ident} = [ sort $by_name_datatype_first @cols ];

  $self->controller->displayable_columns($dis_cols);
}

sub setup_displayable_columns {
  my ($self) = @_;

  foreach my $p (@{ $self->profile }) {
    $self->add_displayable_columns($p->{row_ident}, map { { name => $_ } } keys %{ $p->{profile} });
  }
}

sub add_cvar_columns_to_displayable_columns {
  my ($self) = @_;

  $self->add_displayable_columns(map { { name        => 'cvar_' . $_->name,
                                         description => $::locale->text('#1 (custom variable)', $_->description) } }
                                     @{ $self->all_cvar_configs });
}

sub init_existing_objects {
  my ($self) = @_;

  eval "require " . $self->class;
  $self->existing_objects($self->manager_class->get_all);
}

sub init_class {
  die "class not set";
}

sub init_manager_class {
  my ($self) = @_;

  $self->class =~ m/^SL::DB::(.+)/;
  $self->manager_class("SL::DB::Manager::" . $1);
}

1;

