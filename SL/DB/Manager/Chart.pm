package SL::DB::Manager::Chart;

use strict;

use SL::DB::Helper::Manager;
use base qw(SL::DB::Helper::Manager);

use SL::DB::Helper::Sorted;
use SL::DB::Helper::Paginated;
use SL::DB::Helper::Filtered;
use SL::MoreCommon qw(listify);
use DateTime;
use SL::DBUtils;
use Data::Dumper;

sub object_class { 'SL::DB::Chart' }

__PACKAGE__->make_manager_methods;

__PACKAGE__->add_filter_specs(
  type => sub {
    my ($key, $value) = @_;
    return __PACKAGE__->type_filter($value);
  },
  category => sub {
    my ($key, $value) = @_;
    return __PACKAGE__->category_filter($value);
  },
  selected_category => sub {
    my ($key, $value) = @_;
    return __PACKAGE__->selected_category_filter($value);
  },
  all => sub {
    my ($key, $value) = @_;
    return or => [ map { $_ => $value } qw(accno description) ]
  },
  booked => sub {
    my ($key, $value) = @_;
    return __PACKAGE__->booked_filter($value);
  },
);

sub booked_filter {
  my ($class, $booked) = @_;

  $booked //= 0;
  my @filter;

  if ( $booked ) {
     push @filter, ( id => [ \"SELECT distinct chart_id FROM acc_trans" ] );
  };

  return @filter;
}

sub selected_category_filter {
  my ($class, $selected_categories) = @_;

  my @selected_categories = @$selected_categories;

  # if no category is selected, there is no filter and thus all charts of all
  # categories are displayed, which is what we want.

  return (category => \@$selected_categories);
}

sub type_filter {
  my ($class, $type) = @_;

  # filter by link or several defined custom types
  # special types:
  # bank, guv, balance

  return () unless $type;

  if ('HASH' eq ref $type) {
    # this is to make selection like type => { AR_paid => 1, AP_paid => 1 } work
    $type = [ grep { $type->{$_} } keys %$type ];
  }

  my @types = grep { $_ } listify($type);
  my @filter;

  for my $type (@types) {
    if ( $type eq 'bank' ) {
     push @filter, ( id => [ \"SELECT chart_id FROM bank_accounts" ] );
    } elsif ( $type eq 'guv' ) {
     push @filter, ( category => [ 'I', 'E' ] );
    } elsif ( $type eq 'balance' ) {
     push @filter, ( category => [ 'A', 'Q', 'L' ] );
    } else {
      push @filter, $class->link_filter($type);
    };
  };

  return @filter > 2 ? (or => \@filter) : @filter;
}

sub category_filter {
  my ($class, $category) = @_;

  return () unless $category;

  # filter for chart_picker if a category filter was passed via params

  if ( ref $category eq 'HASH' ) {
    # this is to make a selection like category => { I => 1, E => 1 } work
    $category = [ grep { $category->{$_} } keys %$category ];
  }

  my @categories = grep { $_ } listify($category);

  return (category => \@categories);
}

sub link_filter {
  my ($class, $link) = @_;

  return (or => [ link => $link,
                  link => { like => "${link}:\%"    },
                  link => { like => "\%:${link}"    },
                  link => { like => "\%:${link}:\%" } ]);
}

sub cache_taxkeys {
  my ($self, %params) = @_;

  my $date  = $params{date} || DateTime->today;
  my $cache = $::request->cache('::SL::DB::Chart::get_active_taxkey')->{$date} //= {};

  require SL::DB::TaxKey;
  my $tks = SL::DB::Manager::TaxKey->get_all;
  my %tks_by_id = map { $_->id => $_ } @$tks;

  my $rows = selectall_hashref_query($::form, $::form->get_standard_dbh, <<"", $date);
    SELECT DISTINCT ON (chart_id) chart_id, startdate, id
    FROM taxkeys
    WHERE startdate <= ?
    ORDER BY chart_id, startdate DESC;

  for (@$rows) {
    $cache->{$_->{chart_id}} = $tks_by_id{$_->{id}};
  }
}

sub _sort_spec {
  (
    default  => [ 'accno', 1 ],
    # columns  => {
    #   SIMPLE => 'ALL',
    # },
    nulls    => {},
  );
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

SL::DB::Manager::Chart - Manager class for the model for the C<chart> table

=head1 FUNCTIONS

=over 4

=item C<link_filter $link>

Returns a query builder filter that matches charts whose 'C<link>'
field contains C<$link>. Matching is done so that the exact value of
C<$link> matches but not if C<$link> is only a substring of a
match. Therefore C<$link = 'AR'> will match the column content 'C<AR>'
or 'C<AR_paid:AR>' but not 'C<AR_amount>'.

=back

=head1 BUGS

Nothing here yet.

=head1 AUTHOR

Moritz Bunkus E<lt>m.bunkus@linet-services.deE<gt>

G. Richardson E<lt>information@kivitendo-premium.deE<gt>

=cut
