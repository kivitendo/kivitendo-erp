package SL::Controller::CsvImport::Shipto;

use strict;

use SL::Helper::Csv;

use parent qw(SL::Controller::CsvImport::Base);

use Rose::Object::MakeMethods::Generic
(
 scalar                  => [ qw(table) ],
 'scalar --get_set_init' => [ qw(all_vc) ],
);

sub init_class {
  my ($self) = @_;
  $self->class('SL::DB::Shipto');
}

sub init_all_vc {
  my ($self) = @_;

  $self->all_vc({ customers => SL::DB::Manager::Customer->get_all,
                  vendors   => SL::DB::Manager::Vendor->get_all });
}

sub check_objects {
  my ($self) = @_;

  my %by_id     = map { ( $_->id => $_ ) } @{ $self->all_vc->{customers} }, @{ $self->all_vc->{vendors} };
  my %by_number = ( customers => { map { ( $_->customernumber => $_->id ) } @{ $self->all_vc->{customers} } },
                    vendors   => { map { ( $_->vendornumber   => $_->id ) } @{ $self->all_vc->{vendors}   } } );
  my %by_name   = ( customers => { map { ( $_->name           => $_->id ) } @{ $self->all_vc->{customers} } },
                    vendors   => { map { ( $_->name           => $_->id ) } @{ $self->all_vc->{vendors}   } } );

  foreach my $entry (@{ $self->controller->data }) {
    my $object   = $entry->{object};
    my $raw_data = $entry->{raw_data};

    if ($object->trans_id) {
      $object->trans_id(undef) if !$by_id{ $object->trans_id };
    }

    if (!$object->trans_id) {
      my $vc_id = $by_number{customers}->{ $raw_data->{customernumber} } || $by_number{vendors}->{ $raw_data->{vendornumber} };
      $object->trans_id($vc_id) if $vc_id;
    }

    if (!$object->trans_id) {
      my $vc_id = $by_name{customers}->{ $raw_data->{customer} } || $by_name{vendors}->{ $raw_data->{vendor} };
      $object->trans_id($vc_id) if $vc_id;
    }

    if (!$object->trans_id) {
      push @{ $entry->{errors} }, $::locale->text('Error: Customer/vendor not found');
      next;
    }

    $object->module('CT');

    $entry->{vc} = $by_id{ $object->trans_id };
  }
}

sub check_duplicates {
  my ($self, %params) = @_;

  my $normalizer = sub { my $name = $_[0]; $name =~ s/[\s,\.\-]//g; return $name; };
  my $name_maker = sub { return $normalizer->($_[0]->shiptoname) . '--' . $normalizer->($_[0]->shiptostreet) };

  my %by_id_and_name;
  if ('check_db' eq $self->controller->profile->get('duplicates')) {
    foreach my $type (qw(customers vendors)) {
      foreach my $vc (@{ $self->all_vc->{$type} }) {
        $by_id_and_name{ $vc->id } = { map { ( $name_maker->($_) => 'db' ) } @{ $vc->shipto } };
      }
    }
  }

  foreach my $entry (@{ $self->controller->data }) {
    next if @{ $entry->{errors} };

    my $name = $name_maker->($entry->{object});

    $by_id_and_name{ $entry->{vc}->id } ||= { };
    if (!$by_id_and_name{ $entry->{vc}->id }->{ $name }) {
      $by_id_and_name{ $entry->{vc}->id }->{ $name } = 'csv';

    } else {
      push @{ $entry->{errors} }, $by_id_and_name{ $entry->{vc}->id }->{ $name } eq 'db' ? $::locale->text('Duplicate in database') : $::locale->text('Duplicate in CSV file');
    }
  }
}

sub field_lengths {
  return ( shiptoname         => 75,
           shiptodepartment_1 => 75,
           shiptodepartment_2 => 75,
           shiptostreet       => 75,
           shiptozipcode      => 75,
           shiptocity         => 75,
           shiptocountry      => 75,
           shiptocontact      => 75,
           shiptophone        => 30,
           shiptofax          => 30,
         );
}

1;
