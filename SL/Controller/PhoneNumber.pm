package SL::Controller::PhoneNumber;

use utf8;
use strict;
use parent qw(SL::Controller::Base);

use List::MoreUtils qw(any);
use List::Util qw(first);

use SL::JSON;
use SL::DBUtils;
use SL::Locale::String;
use SL::CTI;

use SL::DB::Contact;
use SL::DB::Customer;
use SL::DB::Vendor;

use Data::Dumper;

sub action_look_up {
  my ($self) = @_;

  my $number = $self->normalize_number($::form->{number} // '');

  return $self->render(\to_json({}), { type => 'json', process => 0 }) if ($number eq '');

  my $result = $self->find_contact_for_number($number)
    //         $self->find_customer_vendor_for_number($number)
    //         {};

  $self->render(\to_json($result), { type => 'json', process => 0 });
}

sub find_contact_for_number {
  my ($self, $number) = @_;

  my @number_fields = qw(cp_phone1 cp_phone2 cp_mobile1 cp_mobile2 cp_fax);

  my $contacts = SL::DB::Manager::Contact->get_all(
    inject_results => 1,
    where          => [ map({ (or => [ "!$_" => undef, "!$_"  => "" ],) } @number_fields) ],
  );

  my @hits;

  foreach my $contact (@{ $contacts }) {
    foreach my $field (@number_fields) {
      next if $self->normalize_number($contact->$field) ne $number;

      push @hits, $contact;
      last;
    }
  }

  return if !@hits;

  my @cv_ids = grep { $_ } map { $_->cp_cv_id } @hits;

  my %customers_vendors =
    map { ($_->id => $_) } (
      @{ SL::DB::Manager::Customer->get_all(where => [ id => \@cv_ids ], inject_results => 1) },
      @{ SL::DB::Manager::Vendor  ->get_all(where => [ id => \@cv_ids ], inject_results => 1) },
    );

  my $chosen = first {
       $_->cp_cv_id
    &&  $customers_vendors{$_->cp_cv_id}
    && !$customers_vendors{$_->cp_cv_id}->obsolete
    && ($_->cp_name !~ m{ungültig}i)
  } @hits;

  $chosen //= $hits[0];

  return {
    full_name => join(' ', grep { $_ ne '' } map { $_ // '' } ($chosen->cp_title, $chosen->cp_givenname, $chosen->cp_name)),
    id        => $chosen->cp_id,
    type      => 'contact',
    map({ my $method = "cp_$_"; ($_ => $chosen->$method // '') } qw(title givenname name phone1 phone2 mobile1 mobile2 fax)),
  };
}

sub find_customer_vendor_for_number {
  my ($self, $number) = @_;

  my @number_fields = qw(phone fax);

  my @customers_vendors = map {
      my $class = "SL::DB::Manager::$_";
      @{ $class->get_all(
           inject_results => 1,
           where          => [ map({ (or => [ "!$_" => undef, "!$_"  => "" ],) } @number_fields) ],
         ) }
    } qw(Customer Vendor);

  my @hits;

  foreach my $customer_vendor (@customers_vendors) {
    foreach my $field (@number_fields) {
      next if $self->normalize_number($customer_vendor->$field) ne $number;

      push @hits, $customer_vendor;
      last;
    }
  }

  return if !@hits;

  my $chosen = first { !$_->obsolete } @hits;
  $chosen  //= $hits[0];

  return {
    full_name => $chosen->name  // '',
    phone1    => $chosen->phone // '',
    fax       => $chosen->fax   // '',
    id        => $chosen->id,
    type      => ref($chosen) eq 'SL::DB::Customer' ? 'customer' : 'vendor',
    map({ ($_ => '') } qw(title givenname name phone2 mobile1 mobile2)),
  };
}

sub normalize_number {
  my ($self, $number) = @_;

  return '' if ($number // '') eq '';

  my $config       = $::lx_office_conf{cti} || {};
  my $idp          = $config->{international_dialing_prefix} // '00';
  my $country_code = $config->{our_country_code}             // '49';

  $number          = SL::CTI->sanitize_number(number => $number);

  return $number if $number =~ m{^$idp};

  $number =~ s{^0+}{};

  return $idp . $country_code . $number;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::Controller::Contact - Looking up information on contacts/customers/vendors based on a phone number

=head1 FUNCTIONS

=over 4

=item C<action_look_up>

This action can be used by external systems such as PBXes in order to
match a calling number to a name. Requires one form parameter to be
passed, C<number>.

The number will then be normalized. This requires that the
international dialing prefix and the server's own country code be set
up in C<kivitendo.conf>, section C<[cti]>. They default to C<00> and
C<49> (Germany) respectively.

Next the function will look up a contact whose normalized numbers
equals the requested number. The fields C<phone1>, C<phone2>,
C<mobile1>, C<mobile2> and C<fax> are considered. Active contacts are
given preference over inactive ones (inactive meaning that they don't
belong to a customer/vendor anymore or that the customer/vendor itself
is flagged as obsolete).

If no contact is found, customers & vendors are searched. Their fields
C<phone> and C<fax> are considered. The first customer/vendor who
isn't flagged as being obsolete is chosen; if there's none, the first
obsolete one is.

The function always sends one JSON-encoded object. If there's no hit
for the number, an empty object is returned. Otherwise the following
fields are present:

=over 4

=item C<id> — the database ID of the corresponding record

=item C<type> — describes the type of record returned; can be either
C<contact>, C<customer> or C<vendor>

=item C<full_name> — for contacts this is the concatenation of the
title, given name and family name; for customers/vendors it's the
company name

=item C<title> — title (empty for customers/vendors)

=item C<givenname> — first/given name (empty for customers/vendors)

=item C<name> — last/family name (empty for customers/vendors)

=item C<phone1> — first phone number (for all object types)

=item C<phone2> — second phone number (empty for customers/vendors)

=item C<mobile1> — first mobile number (empty for customers/vendors)

=item C<mobile2> — second mobile number (empty for customers/vendors)

=item C<fax> — fax number (for all object types)

=back

Here's an example how querying the API via C<curl> might look:

    curl --user user_name:password 'https://…/kivitendo/controller.pl?action=PhoneNumber/look_up&number=0049987655443321'

Note that the request must be authenticated via a valid Kivitendo
login. However, the user doesn't need any special permissions within
Kivitendo; any valid Kivitendo user will do.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

=cut
