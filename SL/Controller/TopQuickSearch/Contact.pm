package SL::Controller::TopQuickSearch::Contact;

use strict;
use parent qw(SL::Controller::TopQuickSearch::Base);

use SL::Controller::CustomerVendor;
use SL::DB::Vendor;
use SL::DBUtils qw(selectfirst_array_query like);
use SL::Locale::String qw(t8);

sub auth { undef }

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
      or => [
        "customer.id" => [ \$cv_query ],
        "vendor.id"   => [ \$cv_query ]
      ],
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

  my @customers = $contact->customers;
  my @vendors   = $contact->vendors;
  my @cv = (@customers, @vendors);

  SL::Controller::CustomerVendor->new->url_for(action => 'edit', id => $cv[0]->id, contact_id => $contact->cp_id, db => $cv[0]->meta->table, fragment => 'contacts');
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

# TODO: multi search

1;
