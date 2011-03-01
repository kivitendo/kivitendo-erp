package SL::Controller::CsvImport::Base;

use strict;

use SL::Helper::Csv;

use parent qw(Rose::Object);

use Rose::Object::MakeMethods::Generic
(
 scalar                  => [ qw(controller file csv) ],
 'scalar --get_set_init' => [ qw(profile existing_objects class manager_class) ],
);

sub run {
  my ($self) = @_;

  my $profile = $self->profile;
  $self->csv(SL::Helper::Csv->new(file                   => $self->file->file_name,
                                  encoding               => $self->controller->profile->get('charset'),
                                  class                  => $self->class,
                                  profile                => $profile,
                                  ignore_unknown_columns => 1,
                                  map { ( $_ => $self->controller->profile->get($_) ) } qw(sep_char escape_char quote_char),
                                 ));
  $self->csv->parse;

  $self->controller->errors([ $self->csv->errors ]) if $self->csv->errors;

  return unless $self->csv->header;

  my $headers         = { headers => [ grep { $profile->{$_} } @{ $self->csv->header } ] };
  $headers->{methods} = [ map { $profile->{$_} } @{ $headers->{headers} } ];
  $self->controller->headers($headers);

  $self->controller->data([ map { { object => $_, errors => [] } } $self->csv->get_objects ]);

  $self->check_objects;
  $self->check_duplicates if $self->controller->profile->get('duplicates', 'no_check') ne 'no_check';
  $self->fix_field_lenghts;
}

sub init_profile {
  my ($self) = @_;

  eval "require " . $self->class;

  my %profile;
  for my $col ($self->class->meta->columns) {
    my $name = $col->isa('Rose::DB::Object::Metadata::Column::Numeric')   ? "$col\_as_number"
      :        $col->isa('Rose::DB::Object::Metadata::Column::Date')      ? "$col\_as_date"
      :        $col->isa('Rose::DB::Object::Metadata::Column::Timestamp') ? "$col\_as_date"
      :                                                                     $col->name;

    $profile{$col} = $name;
  }

  $self->profile(\%profile);
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

sub fix_field_lenghts {
  my ($self) = @_;

  my %field_lengths = $self->field_lengths;
  foreach my $entry (@{ $self->controller->data }) {
    next unless @{ $entry->{errors} };
    map { $entry->{object}->$_(substr($entry->{object}->$_, 0, $field_lengths{$_})) if $entry->{object}->$_ } keys %field_lengths;
  }
}

1;
