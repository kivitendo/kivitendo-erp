package SL::DB::Manager::Contact;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;

sub object_class { 'SL::DB::Contact' }

__PACKAGE__->make_manager_methods;

sub _sort_spec {
  return (
    default     => [ 'full_name', 1 ],
    columns     => {
      SIMPLE    => 'ALL',
      full_name => [ 'lower(contacts.cp_name)', 'lower(contacts.cp_givenname)', ],
      map { ( $_ => "lower(contacts.cp_$_)" ) } qw(abteilung city email fax givenname mobile1 mobile2 name phone1 phone2 position privatemail privatphone project satfax satphone street title zipcode)
    });
}

1;
