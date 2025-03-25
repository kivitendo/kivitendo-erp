package SL::Controller::CsvImport::BaseMulti;

use strict;

use List::MoreUtils qw(pairwise firstidx);

use SL::Helper::Csv;

use parent qw(SL::Controller::CsvImport::Base);

use Rose::Object::MakeMethods::Generic
(
'scalar --get_set_init' => [ qw(cvar_configs_by cvar_columns_by) ],
);

sub run {
  my ($self, %params) = @_;

  $self->test_run($params{test});

  $self->controller->track_progress(phase => 'parsing csv', progress => 0);

  my $profile = $self->profile;

  $self->csv(SL::Helper::Csv->new(file                   => ('SCALAR' eq ref $self->file)? $self->file: $self->file->file_name,
                                  encoding                => $self->controller->profile->get('charset'),
                                  profile                 => $profile,
                                  ignore_unknown_columns  => 1,
                                  strict_profile          => 1,
                                  case_insensitive_header => 1,
                                  map { ( $_ => $self->controller->profile->get($_) ) } qw(sep_char escape_char quote_char),
                                 ));

  $self->controller->track_progress(progress => 10);

  local $::myconfig{numberformat} = $self->controller->profile->get('numberformat');
  local $::myconfig{dateformat}   = $self->controller->profile->get('dateformat');

  $self->csv->parse;

  $self->controller->track_progress(progress => 50);

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

  my $objects  = $self->csv->get_objects;
  if ($self->csv->errors) {
    $self->controller->errors([ $self->csv->errors ]) ;
    return;
  }

  $self->controller->track_progress(progress => 70);

  my @raw_data = @{ $self->csv->get_data };

  $self->controller->track_progress(progress => 80);

  $self->controller->data([ pairwise { { object => $a, raw_data => $b, errors => [], information => [], info_data => {} } } @$objects, @raw_data ]);

  $self->controller->track_progress(progress => 90);

  $self->check_objects;
  if ( $self->controller->profile->get('duplicates', 'no_check') ne 'no_check' ) {
    $self->check_std_duplicates();
    $self->check_duplicates();
  }
  $self->fix_field_lengths;

  $self->controller->track_progress(progress => 100);
}

sub init_manager_class {
  my ($self) = @_;

  my @manager_classes;
  foreach my $class (@{ $self->class }) {
    $class =~ m/^SL::DB::(.+)/;
    push @manager_classes, "SL::DB::Manager::" . $1;
  }
  $self->manager_class(\@manager_classes);
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

  foreach my $data (@{ $self->controller->data }) {
    my $ri = $data->{raw_data}->{datatype};
    map { $self->add_raw_data_columns($ri, $_) if exists $data->{raw_data}->{$_} } @{ $self->cvar_columns_by->{row_ident}->{$ri} };
  }
}

sub init_cvar_configs_by {
  # Must be overridden by derived specialized importer classes.
  return {};
}

sub init_cvar_columns_by {
  my ($self) = @_;

  my $ccb;
  foreach my $p (@{ $self->profile }) {
    my $ri = $p->{row_ident};
    $ccb->{row_ident}->{$ri} = [ map { "cvar_" . $_->name } (@{ $self->cvar_configs_by->{row_ident}->{$ri} }) ];
  }

  return $ccb;
}

sub handle_cvars {
  my ($self, $entry, %params) = @_;

  return if @{ $entry->{errors} };
  return unless $entry->{object}->can('cvars_by_config');

  my %type_to_column = ( text      => 'text_value',
                         textfield => 'text_value',
                         htmlfield => 'text_value',
                         select    => 'text_value',
                         date      => 'timestamp_value_as_date',
                         timestamp => 'timestamp_value_as_date',
                         number    => 'number_value_as_number',
                         bool      => 'bool_value' );

  $params{sub_module} ||= '';

  # autovivify all cvars (cvars_by_config will do that for us)
  my @cvars;
  @cvars = @{ $entry->{object}->cvars_by_config };

  foreach my $config (@{ $self->cvar_configs_by->{row_ident}->{$entry->{raw_data}->{datatype}} }) {
    next unless exists $entry->{raw_data}->{ "cvar_" . $config->name };
    my $value  = $entry->{raw_data}->{ "cvar_" . $config->name };
    my $column = $type_to_column{ $config->type } || die "Program logic error: unknown custom variable storage type";

    my $cvar = SL::DB::CustomVariable->new(config_id => $config->id, $column => $value, sub_module => $params{sub_module});

    # replace autovivified cvar by new one
    my $idx = firstidx { $_->config_id == $config->id } @cvars;
    $cvars[$idx] = $cvar if -1 != $idx;
  }

  $entry->{object}->custom_variables(\@cvars) if @cvars;
}

sub init_profile {
  my ($self) = @_;

  my @profile;
  foreach my $class (@{ $self->class }) {
    eval "require " . $class;

    my %unwanted = map { ( $_ => 1 ) } (qw(itime mtime), map { $_->name } @{ $class->meta->primary_key_columns });

    # TODO: exceptions for AccTransaction and Invoice wh
    if ( $class =~ m/^SL::DB::AccTransaction/ ) {
      my %unwanted_acc_trans = map { ( $_ => 1 ) } (qw(acc_trans_id trans_id cleared fx_transaction ob_transaction cb_transaction itime mtime chart_link tax_id description gldate memo source transdate), map { $_->name } @{ $class->meta->primary_key_columns });
      @unwanted{keys %unwanted_acc_trans} = values %unwanted_acc_trans;
    };
    if ( $class =~ m/^SL::DB::Invoice/ ) {
      # remove fields that aren't needed / shouldn't be set for ar transaction
      my %unwanted_ar = map { ( $_ => 1 ) } (qw(closed currency currency_id datepaid dunning_config_id gldate invnumber_for_credit_note invoice marge_percent marge_total amount netamount paid shippingpoint shipto_id shipvia storno storno_id type cp_id), map { $_->name } @{ $class->meta->primary_key_columns });
      @unwanted{keys %unwanted_ar} = values %unwanted_ar;
    };

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

    $prof{ 'cvar_' . $_->name } = '' for @{ $self->cvar_configs_by->{class}->{$class} };

    $class =~ m/^SL::DB::(.+)/;
    push @profile, {'profile' => \%prof, 'class' => $class, 'row_ident' => $::locale->text($1)};
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
  my ($self, $row_ident) = @_;

  $self->add_displayable_columns($row_ident,
                                 map { { name        => 'cvar_' . $_->name,
                                         description => $::locale->text('#1 (custom variable)', $_->description) } }
                                     @{ $self->cvar_configs_by->{row_ident}->{$row_ident} });
}

sub field_lengths {
  my ($self) = @_;

  my %field_lengths_by_ri = ();

  foreach my $p (@{ $self->profile }) {
    my %field_lengths = map { $_->name => $_->length } grep { $_->type eq 'varchar' } @{ $p->{class}->meta->columns };
    $field_lengths_by_ri{ $p->{row_ident} } = \%field_lengths;
  }

  return %field_lengths_by_ri;
}

sub fix_field_lengths {
  my ($self) = @_;

  my %field_lengths_by_ri = $self->field_lengths;
  foreach my $entry (@{ $self->controller->data }) {
    next unless defined $entry->{errors} && @{ $entry->{errors} };
    my %field_lengths = %{ $field_lengths_by_ri{ $entry->{raw_data}->{datatype} } };
    map { $entry->{object}->$_(substr($entry->{object}->$_, 0, $field_lengths{$_})) if $entry->{object}->$_ } keys %field_lengths;
  }

  return;
}

sub is_multiplexed { 1 }

1;
