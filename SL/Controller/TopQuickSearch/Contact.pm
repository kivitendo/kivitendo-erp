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
        "customers.id" => [ \$cv_query ],
        "vendors.id"   => [ \$cv_query ]
      ],
    ],
    limit => 10,
    with_objects => ['customers', 'vendors'],
    sort_by => 'cp_name',
  );

  return [
    map {
      my $contact = $_;
      map {
        value       => $contact->full_name,
        label       => $contact->full_name . ' (' . $_->displayable_name . ')',
        id          => $contact->cp_id . ';' . $_->meta->table . ';' . $_->id,
      }, $contact->customers, $contact->vendors;
    } @$result
  ];
}

sub select_autocomplete {
  my ($self) = @_;
  my ($contact_id, $db, $cv_id) = split /;/, $::form->{id};

  SL::Controller::CustomerVendor->new->url_for(action => 'edit', id => $cv_id, contact_id => $contact_id, db => $db, fragment => 'contacts');
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
