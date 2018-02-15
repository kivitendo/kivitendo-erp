package SL::Controller::TopQuickSearch::Contact;

use strict;
use parent qw(SL::Controller::TopQuickSearch::Base);

use SL::Controller::CustomerVendor;
use SL::DB::Vendor;
use SL::DBUtils qw(selectfirst_array_query like);
use SL::Locale::String qw(t8);

sub auth { 'customer_vendor_edit' }

sub name { 'contact' }

sub description_config { t8('Contact') }

sub description_field { t8('Contacts') }

sub query_autocomplete {
  my ($self) = @_;

  my $cv_query = <<SQL;
    SELECT id FROM customer
    WHERE (obsolete IS NULL)
       OR (obsolete = FALSE)

    UNION

    SELECT id FROM vendor
    WHERE (obsolete IS NULL)
       OR (obsolete = FALSE)
SQL

  my $result = SL::DB::Manager::Contact->get_all(
    query => [
      or => [
        cp_name      => { ilike => like($::form->{term}) },
        cp_givenname => { ilike => like($::form->{term}) },
        cp_email     => { ilike => like($::form->{term}) },
      ],
      cp_cv_id => [ \$cv_query ],
    ],
    limit => 10,
    sort_by => 'cp_name',
  );

  return [
    map {
     value       => $_->full_name,
     label       => $_->full_name,
     id          => $_->cp_id,
    }, @$result
  ];
}

sub select_autocomplete {
  my ($self) = @_;

  my $contact = SL::DB::Manager::Contact->find_by(cp_id => $::form->{id});

  SL::Controller::CustomerVendor->new->url_for(action => 'edit', id => $contact->cp_cv_id, contact_id => $contact->cp_id, db => db_for_contact($contact), fragment => 'contacts');
}

sub do_search {
  my ($self) = @_;

  my $results = $self->query_autocomplete;

  if (@$results != 1) {
    return SL::Controller::CustomerVendor->new->url_for(
      controller      => 'ct.pl',
      action          => 'list_contacts',
      'filter.status' => 'active',
      search_term     => $::form->{term},
    );
  } else {
    $::form->{id} = $results->[0]{id};
    return $self->select_autocomplete;
  }
}


sub db_for_contact {
  my ($contact) = @_;

  my ($customer, $vendor) = selectfirst_array_query($::form, $::form->get_standard_dbh, <<SQL, ($contact->cp_cv_id)x2);
    SELECT (SELECT COUNT(id) FROM customer WHERE id = ?), (SELECT COUNT(id) FROM vendor WHERE id = ?);
SQL

  die 'Contact is orphaned, cannot link to it'         if !$customer && !$vendor;

  $customer ? 'customer' : 'vendor';
}

# TODO: multi search

1;
