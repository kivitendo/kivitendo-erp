package SL::BackgroundJob::ExportContactsRadicale;

use strict;
use warnings;

use parent qw(SL::BackgroundJob::Base);

use File::Path qw(make_path remove_tree);
use File::Spec::Functions qw(catfile);

use SL::DB;
use SL::DB::Manager::Customer;
use SL::DB::Manager::Contact;
use SL::DB::Manager::Vendor;
use SL::DBUtils qw(selectall_hashref_query);

# Helper to handle errors from File::Path::{make_path,remove_tree}
sub _handle_file_error {
  my ($err, $msg_template) = @_;
  my @out;

  foreach my $error ( @{$err} ) {
    my ($file, $msg) = %{$error};
    push @out, $msg_template . " $file: $msg";
  }
  die join(", ", @out);
}

# Creates the Radicale directory structure and populates it with minimum metadata.
sub prepare_contacts_dir {
  my ($self) = @_;
  my $contacts_dir = $self->{dav_contacts_dir};
  my $props_file = catfile($contacts_dir, ".Radicale.props");
  my $props='{"D:displayname": "contacts", "tag": "VADDRESSBOOK",  "{http://inf-it.com/ns/ab/}addressbook-color": "#56f9acff"}';
  my $err;

  # Start from a clean slate unless explicitly configured to retain contacts that
  # no longer exist in Kivitendo.
  unless ( ($self->{job_obj}->data_as_hash->{nopurge}) and ($self->{job_obj}->data_as_hash->{nopurge} == 'true') ) {
    remove_tree($self->{dav_client_dir}, {error => \$err});
    if ( scalar @{$err} > 0 ) {
      _handle_file_error($err, "Couldn't remove");
    }

  }

  make_path($contacts_dir, {chmod => 0770, error => \$err});

  if ( scalar @{$err} > 0 ) {
    _handle_file_error($err, "Couldn't mkdir");
  }

  open PF, ">", $props_file or die "Couldn't open $props_file for writing: $!\n";
  print PF $props;
  close PF;
}

# Translates Kivitendo column names (and synthetic 'name_with_org') to VCARD field names.
sub _translate_params {
  my ($param, @values) = @_;

  my %fstrings = (
    'phone' => 'TEL:%s',
    'name' => 'FN:%s',
    'email' => 'EMAIL:%s',
    'name_with_org' => 'FN:%s (%s)'
  );

  return(sprintf($fstrings{$param}, @values));
}

# Generates a vcard from params hash and saves it to file
sub save_vcard {
  my ($self, $params) = @_;
  my $cardfile = catfile($self->{dav_contacts_dir}, $params->{phone});

  for my $param ( keys %{$params} )
    {
    $params->{$param} = Encode::encode('UTF-8', $params->{$param});
  }

  my @card = (
    "BEGIN:VCARD",
    "VERSION:4.0",
    "UID:$params->{phone}",
    _translate_params('phone', ($params->{phone}))
  );

  if ( $params->{email} ) {
    push @card, _translate_params('email', $params->{email});
  }

  if ( $params->{org} ) {
    # Qualify contacts associated with an organization with their
    # organization's name
    push @card, _translate_params('name_with_org', ($params->{name}, $params->{org}));
  } else {
    push @card, _translate_params('name', $params->{name});
  }

  push @card, "END:VCARD";

  open CARD, ">", $cardfile or die "Couldn't open $cardfile for writing: $!\n";
  print CARD join("\n", @card);
  close CARD;
}

# Helper to ensure canonical representation of all phone numbers
sub _normalize_number {
  my $number = shift(@_);
  my $prefix = $::lx_office_conf{cti}->{our_country_code};

  $number =~ s/[^0-9+]//g;
  $number =~ s/^0//;
  if ( $number =~ /^\d/ ) { $number = "+$prefix" . $number; }

  return $number;
}

# Aggregate contacts from the database and call save_vcard on each
sub save_contacts {
  my ($self) = @_;
  # contacts hash, indexed by phone number as unique ID.
  my %numbers;

  my $dbh = $self->{dbh};

  my $query = <<SQL;
  SELECT name, phone, email from customer
    UNION ALL
  SELECT name, phone, email from vendor;
SQL

  my $result = selectall_hashref_query($::form, $dbh, $query);

  foreach my $row (@{$result}) {
    next unless $row->{phone};
    my $phone = _normalize_number $row->{phone};

    $numbers{$phone} = {};

    $numbers{$phone}->{name} = $row->{name};
    $numbers{$phone}->{phone} = $phone;
    # Save email address if present
    if ( $row->{email} ) {
      $numbers{$phone}->{email} = $row->{email};
    }
  }

  $result = SL::DB::Manager::Contact->get_all();

  foreach my $row (@{$result}) {
    next unless $row->{cp_phone1};
    my $phone = _normalize_number $row->{cp_phone1};
    $numbers{$phone} = {};

    $numbers{$phone}->{name} = ${row}->{cp_givenname} . " " . ${row}->{cp_name};
    $numbers{$phone}->{phone} = $phone;

    # Save email address if present
    if ( $row->{cp_email} ) {
      $numbers{$phone}->{email} = $row->{cp_email};
    }

    # Set organization attribute
    my $customer = SL::DB::Manager::Customer->find_by('id' => ${row}->{cp_cv_id});
    my $vendor = SL::DB::Manager::Vendor->find_by('id' => ${row}->{cp_cv_id});
    my $ref = $customer ? $customer : $vendor;
    $numbers{$phone}->{org} = $ref->{name};
  }

  foreach my $number (keys %numbers) {
    $self->save_vcard($numbers{$number});
  }

  return;
}

sub run {
  my ($self, $job_obj) = @_;
  $self->{job_obj} = $job_obj;

  $self->{dbh} = SL::DB->client->dbh;

  # Use client name for directory name because there should only ever be one
  # CardDAV directory per client.
  $self->{dav_client_dir} = catfile($::lx_office_conf{radicale}->{radicale_dir},
                        "collection-root",
                        $::auth->client->{name});

  $self->{dav_contacts_dir} = catfile($self->{dav_client_dir},
                        "contacts");

  $self->prepare_contacts_dir();
  $self->save_contacts();

  if ($self->{errors}) {
      # on error we have to inform the user
      $self->send_email();
      die $self->{errors};
  }

  return;
}

1;

__END__

=head1 NAME

SL::BackgroundJob::ExportContactsRadicale - Export all customer and vendor
contacts in a file format suitable for the CardDAV server Radicale

=head1 SYNOPSIS

  use SL::BackgroundJob::ExportContactsRadicale;
  SL::BackgroundJob::ExportContactsRadicale->new->run;;

=head1 DESCRIPTION

This background jobs exports all customer and vendor contacts (including
contact persons) in the Kivitendo client's data base to a directory in the file
system. This data is keyed by phone number to avoid duplicates. If the same
phone number occurs twice for both a vendor and a customer, only one entry will
be created. The data is structured such that the L<Radicale|https://radicale.org/>
CalDAV/CardDAV server can use it as an address book backing store  for its
C<multifilesystem> storage backend.

=head1 CONFIGURATION

=head2 Job data

=over 5

=item C<nopurge: true> - do not purge contacts that no longer exist in the client's database

=back

=head2 kivitendo.conf

 [cti]
 # This country code will be used to create a canonical representation of phone numbers
 our_countcry_code = 49

 [radicale]
 # Root directory for Radicale CardDAV server (the ExportContactsRadicale
 # background job will export contacts to this directory). Must be writeable by
 # the user Kivitendo runs as.
 radicale_dir = radicale/

=head2 Radicale

This is a very bare bones configuration example for radicale. For the purposes
of this documentation we will assume both Kivitendo and radicale run as user
C<www-data>. We will further assume that the Kivitendo client's name is
C<myclient>.

=head3 Preparation

First of all, we need to ensure the designated data dir exists and both
Kivitendo and Radicale can write to it:

  mkdir -p /var/www/html/kivitendo-erp/radicale
  chown www-data /var/www/html/kivitendo-erp/radicale
  chmod 770 /var/www/html/kivitendo-erp/radicale

Next we need to set up a Radicale user for C<myclient> and give it a password:

  htpasswd -c -B /etc/radicale/users myclient

=head3 Minimum /etc/radicale/config

  [server]
  hosts = 0.0.0.0:5232

  [auth]
  type = htpasswd

  [storage]
  filesystem_folder = /var/www/html/kivitendo-erp/radicale

=head3 Minimum /etc/radicale/rights

  # Read/write access to root collection for all users
  [root]
  user = .+
  collection =
  permission = r

  # Read access to principal for all users
  [principal]
  user = .+
  collection = ^%(login)s(/.+)?$
  permission = r

=head3 Start up radicale

  radicale -f -D

=head1 AUTHOR

  Johannes Grassler <info@computer-grassler.de>

=cut
