package SL::Controller::TopQuickSearch::PhoneNumber;

use strict;
use parent qw(SL::Controller::TopQuickSearch::Base);

use SL::Controller::TopQuickSearch::Customer;
use SL::Controller::TopQuickSearch::Vendor;
use SL::DB::Customer;
use SL::DB::Vendor;
use SL::Locale::String qw(t8);
use SL::Util qw(trim);

sub auth { undef }

sub name { 'phone_number' }

sub description_config { t8('All phone numbers') }

sub description_field { t8('All phone numbers') }

sub query_autocomplete {
  my ($self) = @_;

  my @results;
  my $search_term = trim($::form->{term});
  $search_term    =~ s{\p{WSpace}+}{}g;
  $search_term    = join ' *', split(//, $search_term);

  foreach my $model (qw(Customer Vendor)) {
    my $manager = 'SL::DB::Manager::' . $model;
    my $result  = $manager->get_all(
      query => [ or => [ 'obsolete' => 0, 'obsolete' => undef ],
                 or => [ phone                     => { imatch => $search_term },
                         fax                       => { imatch => $search_term },
                         'contacts.cp_phone1'      => { imatch => $search_term },
                         'contacts.cp_phone2'      => { imatch => $search_term },
                         'contacts.cp_fax'         => { imatch => $search_term },
                         'contacts.cp_mobile1'     => { imatch => $search_term },
                         'contacts.cp_mobile2'     => { imatch => $search_term },
                         'contacts.cp_satphone'    => { imatch => $search_term },
                         'contacts.cp_satfax'      => { imatch => $search_term },
                         'contacts.cp_privatphone' => { imatch => $search_term },
                 ] ],
      with_objects => ['contacts']);

    push @results, map {
      value => $_->displayable_name,
      label => $_->displayable_name,
      id    => lc($model) . '_' . $_->id,
    }, @$result;
  }

  return \@results;
}

sub select_autocomplete {
  my ($self) = @_;

  if ($::form->{id} =~ m{^(customer|vendor)_(\d+)$}) {
    my $type      = $1;
    my $id        = $2;
    $::form->{id} = $id;

    if ($type eq 'customer') {
      SL::Controller::TopQuickSearch::Customer->new->select_autocomplete;
    } elsif ($type eq 'vendor') {
      SL::Controller::TopQuickSearch::Vendor->new->select_autocomplete;
    }
  }
}

sub do_search {
  my ($self) = @_;

  my $results = $self->query_autocomplete;

  if (@$results == 1) {
    $::form->{id} = $results->[0]{id};
    return $self->select_autocomplete;
  }
}

# TODO: result overview page

1;
