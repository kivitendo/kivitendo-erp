package SL::Controller::CsvImport::Contact;

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
  $self->class('SL::DB::Contact');
}

sub init_all_vc {
  my ($self) = @_;

  $self->all_vc({ customers => SL::DB::Manager::Customer->get_all(with_objects => [ 'contacts' ]),
                  vendors   => SL::DB::Manager::Vendor->get_all(  with_objects => [ 'contacts' ]) });
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

    my $name     =  $object->cp_name;
    $name        =~ s/^\s+//;
    $name        =~ s/\s+$//;

    if (!$name) {
      push @{ $entry->{errors} }, $::locale->text('Error: Name missing');
      next;
    }

    if ($object->cp_cv_id) {
      $object->cp_cv_id(undef) if !$by_id{ $object->cp_cv_id };
    }

    if (!$object->cp_cv_id) {
      $::lxdebug->message(0, "cnum" . $raw_data->{customernumber});
      my $vc_id = $by_number{customers}->{ $raw_data->{customernumber} } || $by_number{vendors}->{ $raw_data->{vendornumber} };
      $object->cp_cv_id($vc_id) if $vc_id;
    }

    if (!$object->cp_cv_id) {
      my $vc_id = $by_name{customers}->{ $raw_data->{customer} } || $by_name{vendors}->{ $raw_data->{vendor} };
      $object->cp_cv_id($vc_id) if $vc_id;
    }

    if (!$object->cp_cv_id) {
      push @{ $entry->{errors} }, $::locale->text('Error: Customer/vendor not found');
      next;
    }

    $entry->{vc} = $by_id{ $object->cp_cv_id };

    if (($object->cp_gender ne 'm') && ($object->cp_gender ne 'f')) {
      push @{ $entry->{errors} }, $::locale->text('Error: Gender (cp_gender) missing or invalid');
      next;
    }
  }
}

sub check_duplicates {
  my ($self, %params) = @_;

  my $normalizer = sub { my $name = $_[0]; $name =~ s/[\s,\.\-]//g; return $name; };

  my %by_id_and_name;
  if ('check_db' eq $self->controller->profile->get('duplicates')) {
    foreach my $type (qw(customers vendors)) {
      foreach my $vc (@{ $self->all_vc->{$type} }) {
        $by_id_and_name{ $vc->id } = { map { ( $normalizer->($_->cp_name) => 'db' ) } @{ $vc->contacts } };
      }
    }
  }

  foreach my $entry (@{ $self->controller->data }) {
    next if @{ $entry->{errors} };

    my $name = $normalizer->($entry->{object}->cp_name);

    $by_id_and_name{ $entry->{vc}->id } ||= { };
    if (!$by_id_and_name{ $entry->{vc}->id }->{ $name }) {
      $by_id_and_name{ $entry->{vc}->id }->{ $name } = 'csv';

    } else {
      push @{ $entry->{errors} }, $by_id_and_name{ $entry->{vc}->id }->{ $name } eq 'db' ? $::locale->text('Duplicate in database') : $::locale->text('Duplicate in CSV file');
    }
  }
}

sub field_lengths {
  return ( cp_title     => 75,
           cp_givenname => 75,
           cp_name      => 75,
           cp_phone1    => 75,
           cp_phone2    => 75,
           cp_gender    =>  1,
         );
}

1;
