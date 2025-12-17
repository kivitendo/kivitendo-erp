package SL::DB::Helper::CustomerVendorContacts;

use strict;
use Carp;

use constant CONTACTS_RELATIONSHIP     => '__contacts_rel';
use constant MAIN_CONTACT_RELATIONSHIP => '__main_contact_rel';

sub import {
  my ($class, %params) = @_;
  my $caller_package = caller;

  defined $caller_package           or croak 'need to be included from a caller reference';

  exists $params{join_package}      or croak 'need Rose model of the join table';
  exists $params{join_accessor}     or croak 'need the column accessor of the join table to customer/vendor';

  make_relationships($caller_package, %params);
  make_contacts($caller_package, %params);
  make_main_contact($caller_package, %params);
  make_link_contact($caller_package, %params);
  make_detach_contact($caller_package, %params);
}

sub make_relationships {
  my ($caller_package, %params) = @_;

  my $cv = $params{join_package} eq 'SL::DB::CustomerContact' ? 'customer' : 'vendor';

  $caller_package->meta->add_relationships(
     CONTACTS_RELATIONSHIP() => {
      type         => 'many to many',
      map_class    => $params{join_package},
      manager_args => { sort_by => 'lower(contacts.cp_name)' },
    },
    MAIN_CONTACT_RELATIONSHIP() => {
      type         => 'many to many',
      map_class    => $params{join_package},
      query_args   => [ "${cv}_contacts.main" => 1 ],
    }
  );

  no strict 'refs';
  *{ $caller_package . '::contacts_rel_name' } =  sub {
    return CONTACTS_RELATIONSHIP()
  }
}

sub make_contacts {
  my ($caller_package, %params) = @_;

  no strict 'refs';
  *{ $caller_package . '::contacts' } =  sub {
    my ($self) = @_;

    die 'not an accessor' if @_ > 1;
    $self->${\ CONTACTS_RELATIONSHIP() };
  }
}

sub make_main_contact {
  my ($caller_package, %params) = @_;

  no strict 'refs';
  *{ $caller_package . '::main_contact' } =  sub {
    my ($self) = @_;

    die 'not an accessor' if @_ > 1;
    $self->${\ MAIN_CONTACT_RELATIONSHIP() }->[0];
  }
}

sub make_link_contact {
  my ($caller_package, %params) = @_;

  my $join_accessor = $params{join_accessor};
  my $join_package  = $params{join_package};

  no strict 'refs';
  *{ $caller_package . '::link_contact' } =  sub {
    my ($self, $contact, %params) = @_;

    require SL::DB::CustomerContact;
    require SL::DB::VendorContact;
    my $join_manager  = $join_package->_get_manager_class;

    my $existing = $join_manager->get_first(query => [ $join_accessor => $self->id, contact_id => $contact->cp_id ]);
    $existing //= $join_package->new($join_accessor => $self->id, contact_id => $contact->cp_id);

    if (exists $params{main}) {
      $existing->main($params{main});
    }

    $existing->save;
  }
}

sub make_detach_contact {
  my ($caller_package, %params) = @_;

  my $join_accessor = $params{join_accessor};
  my $join_package  = $params{join_package};

  no strict 'refs';
  *{ $caller_package . '::detach_contact' } =  sub {
    my ($self, $contact) = @_;

    require SL::DB::CustomerContact;
    require SL::DB::VendorContact;
    my $join_manager  = $join_package->_get_manager_class;

    $join_manager->delete_all(where => [ $join_accessor => $self->id, contact_id => $contact->cp_id ]);
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::Helper::CustomerVendorContacts - Mixin to provide access methods for m:n contacts for customer and vendor

=head1 SYNOPSIS

  # use in a primary class
  use SL::DB::Helper::CustomerVendorContacts (
    join_package   => 'SL::DB::CustomerContact', # the Rose package of the join table
    join_accessor  => 'customer_id',             # fkey/accessor from the join table to the customer/vendor package
  );

  # now these methods exist in the main package:
  my $contacts_aref = $customer->contacts;      # read only accessor
  my $main_contact  = $customer->main_contact;  # read only accessor

  $customer->link_contact($contact);            # links $customer and $contact
  $customer->detach_contact($contact);          # detached $customer and $contact without deleting either


=head1 DESCRIPTION

This module provides methods to deal with m:n linked customer/vendor and contacts

This is necessary because Rose doesn't deal well with many-to-many relationships beyond the most basic accessors.

=head1 INSTALLED METHODS

=over 4

=item C<contacts>

This is a read-only wrapper around the internal Rose relationship to get all
contacts. It can be used like a normal one-to-many relationship like
C<<Order->orderitems>>, but is made readonly for safety reasons, as write
access by Rose would be unsafe.

=item C<main_contact>

Similar to C<contacts> this is a read-only wrapper to get the main contact if
it exists. Return undef otherwise.

=item C<link_contact $contact PARAMS>

Links the given contact to the C<$self> object. C<$contact> must be a C<SL::DB::Contact> object.

C<link_contact> is idempotent, if C<$self> and C<$contact> are already linked, it does nothing.

If C<PARAMS> contains C<main>, this contact will be linked as the main contact person.

=item C<detach_contact>

Detaches the given contact from the C<$self> object. C<$contact> must be a C<SL::DB::Contact> object.

C<detach_contact> is idempotent, if C<$self> and C<$contact> are already not linked, it does nothing.

=item C<contacts_rel_name>

Returns the internal name of the hidden actual many-to-many relationship
for use in complex joining queries. See L</RECIPES>.

=back

=head1 RECIPES

Since the internal contacts relationship is hidden for safety reasons,
doing complex joining queries involving contacts is not as easy as before.

If you really need to access those, you can use the return of C<contacts_rel_name> in a query:

  my $contacts = $customer->contacts_rel_name;
  SL::DB::Manager::Customer->get_all(
    with_objects => [ $contacts ],
    query => [ $contacts.cp_name => 'test' ]
  );

=head1 BUGS AND CAVEATS

=over 4

=item * Link/Detach are immediate instead of deferred

Would need deeper hacking into the Rose hook mechanism.

=back

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>,

=cut
