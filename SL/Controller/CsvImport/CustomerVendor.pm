package SL::Controller::CsvImport::CustomerVendor;

use strict;

use SL::Helper::Csv;

use parent qw(SL::Controller::CsvImport::Base);

use Rose::Object::MakeMethods::Generic
(
 scalar => [ qw(table) ],
);

sub run {
  my ($self) = @_;

  $self->table($self->controller->profile->get('table') eq 'customer' ? 'customer' : 'vendor');
  $self->class('SL::DB::' . ucfirst($self->table));

  $self->SUPER::run;
}

sub check_objects {
  my ($self) = @_;

  my $numbercolumn  = $self->controller->profile->get('table') . "number";
  my %vcs_by_number = map { ( $_->$numbercolumn => 1 ) } @{ $self->existing_objects };

  foreach my $entry (@{ $self->controller->data }) {
    my $object = $entry->{object};

    my $name =  $object->name;
    $name    =~ s/^\s+//;
    $name    =~ s/\s+$//;
    if (!$name) {
      push @{ $entry->{errors} }, $::locale->text('Error: Name missing');
      next;
    }

    if ($vcs_by_number{ $object->$numbercolumn }) {
      $entry->{object}->$numbercolumn('####');
    } else {
      $vcs_by_number{ $object->$numbercolumn } = $object;
    }
  }
}

sub check_duplicates {
  my ($self, %params) = @_;

  my $normalizer = sub { my $name = $_[0]; $name =~ s/[\s,\.\-]//g; return $name; };

  my %by_name;
  if ('check_db' eq $self->controller->profile->get('duplicates')) {
    %by_name = map { ( $normalizer->($_->name) => 1 ) } @{ $self->existing_objects };
  }

  foreach my $entry (@{ $self->controller->data }) {
    next if @{ $entry->{errors} };

    my $name = $normalizer->($entry->{object}->name);
    if (!$by_name{$name}) {
      $by_name{$name} = 1;

    } else {
      push @{ $entry->{errors} }, $::locale->text('Duplicate');
    }
  }
}

sub save_objects {
  my ($self, %params) = @_;

  my $numbercolumn   = $self->table . 'number';
  my $with_number    = [ grep { $_->{object}->$numbercolumn ne '####' } @{ $self->controller->data } ];
  my $without_number = [ grep { $_->{object}->$numbercolumn eq '####' } @{ $self->controller->data } ];

  map { $_->{object}->$numbercolumn('') } @{ $without_number };

  $self->SUPER::save_objects(data => $with_number);
  $self->SUPER::save_objects(data => $without_number);
}

1;
