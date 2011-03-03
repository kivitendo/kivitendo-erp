package SL::Controller::CsvImport::Base;

use strict;

use List::MoreUtils qw(pairwise);

use SL::Helper::Csv;
use SL::DB::Language;
use SL::DB::PaymentTerm;

use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic
(
 scalar                  => [ qw(controller file csv) ],
 'scalar --get_set_init' => [ qw(profile displayable_columns existing_objects class manager_class cvar_columns all_cvar_configs all_languages payment_terms_by) ],
);

sub run {
  my ($self) = @_;

  my $profile = $self->profile;
  $self->csv(SL::Helper::Csv->new(file                   => $self->file->file_name,
                                  encoding               => $self->controller->profile->get('charset'),
                                  class                  => $self->class,
                                  profile                => $profile,
                                  ignore_unknown_columns => 1,
                                  strict_profile         => 1,
                                  map { ( $_ => $self->controller->profile->get($_) ) } qw(sep_char escape_char quote_char),
                                 ));
  $self->csv->parse;

  $self->controller->errors([ $self->csv->errors ]) if $self->csv->errors;

  return unless $self->csv->header;

  my $headers         = { headers => [ grep { $profile->{$_} } @{ $self->csv->header } ] };
  $headers->{methods} = [ map { $profile->{$_} } @{ $headers->{headers} } ];
  $headers->{used}    = { map { ($_ => 1) }      @{ $headers->{headers} } };
  $self->controller->headers($headers);
  $self->controller->raw_data_headers({ used => { }, headers => [ ] });

  # my @data;
  # foreach my $object ($self->csv->get_objects)
  my @objects  = $self->csv->get_objects;
  my @raw_data = @{ $self->csv->get_data };
  $self->controller->data([ pairwise { { object => $a, raw_data => $b, errors => [] } } @objects, @raw_data ]);

  $self->check_objects;
  $self->check_duplicates if $self->controller->profile->get('duplicates', 'no_check') ne 'no_check';
  $self->fix_field_lengths;
}

sub add_columns {
  my ($self, @columns) = @_;

  my $h = $self->controller->headers;

  foreach my $column (grep { !$h->{used}->{$_} } @columns) {
    $h->{used}->{$column} = 1;
    push @{ $h->{methods} }, $column;
    push @{ $h->{headers} }, $column;
  }
}

sub add_raw_data_columns {
  my ($self, @columns) = @_;

  my $h = $self->controller->raw_data_headers;

  foreach my $column (grep { !$h->{used}->{$_} } @columns) {
    $h->{used}->{$column} = 1;
    push @{ $h->{headers} }, $column;
  }
}

sub add_cvar_raw_data_columns {
  my ($self) = @_;

  map { $self->add_raw_data_columns($_) if exists $self->controller->data->[0]->{raw_data}->{$_} } @{ $self->cvar_columns };
}

sub init_cvar_columns {
  my ($self) = @_;

  return [ map { "cvar_" . $_->name } (@{ $self->all_cvar_configs }) ];
}

sub init_all_languages {
  my ($self) = @_;

  return SL::DB::Manager::Language->get_all;
}

sub init_payment_terms_by {
  my ($self) = @_;

  my $all_payment_terms = SL::DB::Manager::PaymentTerm->get_all;
  return { map { my $col = $_; ( $col => { map { ( $_->$col => $_ ) } @{ $all_payment_terms } } ) } qw(id description) };
}

sub handle_cvars {
  my ($self, $entry) = @_;

  return unless $self->can('all_cvar_configs');

  my %type_to_column = ( text      => 'text_value',
                         textfield => 'text_value',
                         select    => 'text_value',
                         date      => 'timestamp_value_as_date',
                         timestamp => 'timestamp_value_as_date',
                         number    => 'number_value_as_number',
                         bool      => 'bool_value' );

  my @cvars;
  foreach my $config (@{ $self->all_cvar_configs }) {
    next unless exists $entry->{raw_data}->{ "cvar_" . $config->name };
    my $value  = $entry->{raw_data}->{ "cvar_" . $config->name };
    my $column = $type_to_column{ $config->type } || die "Program logic error: unknown custom variable storage type";

    push @cvars, SL::DB::CustomVariable->new(config_id => $config->id, $column => $value);
  }

  $entry->{object}->custom_variables(\@cvars);
}

sub init_profile {
  my ($self) = @_;

  eval "require " . $self->class;

  my %unwanted = map { ( $_ => 1 ) } (qw(itime mtime), map { $_->name } @{ $self->class->meta->primary_key_columns });
  my %profile;
  for my $col ($self->class->meta->columns) {
    next if $unwanted{$col};

    my $name = $col->isa('Rose::DB::Object::Metadata::Column::Numeric')   ? "$col\_as_number"
      :        $col->isa('Rose::DB::Object::Metadata::Column::Date')      ? "$col\_as_date"
      :        $col->isa('Rose::DB::Object::Metadata::Column::Timestamp') ? "$col\_as_date"
      :                                                                     $col->name;

    $profile{$col} = $name;
  }

  $self->profile(\%profile);
}

sub add_displayable_columns {
  my ($self, @columns) = @_;

  my @cols       = @{ $self->controller->displayable_columns || [] };
  my %ex_col_map = map { $_->{name} => $_ } @cols;

  foreach my $column (@columns) {
    if ($ex_col_map{ $column->{name} }) {
      @{ $ex_col_map{ $column->{name} } }{ keys %{ $column } } = @{ $column }{ keys %{ $column } };
    } else {
      push @cols, $column;
    }
  }

  $self->controller->displayable_columns([ sort { $a->{name} cmp $b->{name} } @cols ]);
}

sub setup_displayable_columns {
  my ($self) = @_;

  $self->add_displayable_columns(map { { name => $_ } } keys %{ $self->profile });
}

sub add_cvar_columns_to_displayable_columns {
  my ($self) = @_;

  return unless $self->can('all_cvar_configs');

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

sub check_objects {
}

sub check_duplicates {
}

sub check_payment {
  my ($self, $entry) = @_;

  my $object = $entry->{object};

  # Check whether or not payment ID is valid.
  if ($object->payment_id && !$self->payment_terms_by->{id}->{ $object->payment_id }) {
    push @{ $entry->{errors} }, $::locale->text('Error: Invalid payment terms');
    return 0;
  }

  # Map name to ID if given.
  if (!$object->payment_id && $entry->{raw_data}->{payment}) {
    my $terms = $self->payment_terms_by->{description}->{ $entry->{raw_data}->{payment} };

    if (!$terms) {
      push @{ $entry->{errors} }, $::locale->text('Error: Invalid payment terms');
      return 0;
    }

    $object->payment_id($terms->id);
  }

  return 1;
}

sub save_objects {
  my ($self, %params) = @_;

  my $data = $params{data} || $self->controller->data;

  foreach my $entry (@{ $data }) {
    next if @{ $entry->{errors} };

    if (!$entry->{object}->save) {
      push @{ $entry->{errors} }, $::locale->text('Error when saving: #1', $entry->{object}->db->error);
    } else {
      $self->controller->num_imported($self->controller->num_imported + 1);
    }
  }
}

sub field_lengths {
  return ();
}

sub fix_field_lengths {
  my ($self) = @_;

  my %field_lengths = $self->field_lengths;
  foreach my $entry (@{ $self->controller->data }) {
    next unless @{ $entry->{errors} };
    map { $entry->{object}->$_(substr($entry->{object}->$_, 0, $field_lengths{$_})) if $entry->{object}->$_ } keys %field_lengths;
  }
}

1;
