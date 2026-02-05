use Test::More;

use strict;

use lib 't';
use utf8;

use Carp;
use Data::Dumper;
use List::MoreUtils qw(uniq);
use Support::TestSetup;
use Test::Exception;
use SL::Dev::ALL qw(:ALL);

Support::TestSetup::login();

my @customers = map { new_customer()->save } 1..10;
my @vendors   = map { new_vendor()->save   } 1..10;
my @contacts  = map { SL::DB::Contact->new->save  } 1..20;


# link all contacts to their original customer/vendor
for (0..9) {
  $customers[$_]->link_contact($contacts[$_]);
  $vendors[$_]->link_contact($contacts[10+$_]);
}

# reload all customer/vendor
$_->load for @customers, @vendors;

# check that all of them now have one contact
for (@customers, @vendors) {
  is 1, scalar @{ $_->contacts }, "customer/vendor have each one contact";
}

# now link all contacts to the first customer
$customers[0]->link_contact($_) for @contacts;

# check that now 20 customer_contacts exist with this id
is 20, SL::DB::Manager::CustomerContact->get_all_count(query => [ customer_id => $customers[0]->id ]), "20 customer contacts exist";

# first customer should now have 20 contacts (the one from before _NOT_ duplicate)
is 20, scalar @{ SL::DB::Customer->new(id => $customers[0]->id)->load->contacts }, "customer 1 now has 20 contacts";

for (@customers[1..9], @vendors) {
  is 1, scalar @{ $_->contacts }, "all others still have one";
}

# check that there's no main contact
is undef, $customers[0]->main_contact, "customer has no main contact";

# relink the first one as main contact
$customers[0]->link_contact($contacts[0], main => 1);

# veryfy that the saved element has the main flag
ok !!SL::DB::Manager::CustomerContact->get_first(query => [ customer_id => $customers[0]->id, contact_id => $contacts[0]->cp_id ]), "customer 1 now has 20 contacts";

ok !!SL::DB::Customer->new(id => $customers[0]->id)->load->main_contact, "customer object now has one main contact";

# now detach all of them, even the ones that were never linked
for my $cv (@customers, @vendors) {
  $cv->detach_contact($_) for @contacts;
}

# cleanup:
$_->delete for @contacts, @customers, @vendors;


done_testing();

1;
