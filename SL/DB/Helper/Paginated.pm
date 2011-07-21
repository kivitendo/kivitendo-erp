package SL::DB::Helper::Paginated;

use strict;

require Exporter;
our @ISA    = qw(Exporter);
our @EXPORT = qw(paginate);

use List::MoreUtils qw(any);

sub paginate {
  my ($self, %params) = @_;
  my $page = $params{page} || 1;
  my %args = %{ $params{args} || {} };

  my $ret = { };

  $ret->{per_page} = per_page($self, %params);
  $ret->{max}    = ceil($self->get_all_count(%args), $ret->{per_page}) || 1;
  $ret->{cur}    = $page < 1 ? 1
                 : $page > $ret->{max} ? $ret->{max}
                 : $page;
  $ret->{common} = make_common_pages($ret->{cur}, $ret->{max});

  $params{args}{page}     = $ret->{cur};
  $params{args}{per_page} = $ret->{per_page};
  delete $params{args}{limit};
  delete $params{args}{offset};

  return $ret;
}

sub per_page {
  my ($self, %params) = @_;

  return $params{per_page} if exists $params{per_page};
  return $self->default_objects_per_page;
}

sub ceil {
  my ($a, $b) = @_;
  use integer;

  return 1 unless $b;
  return $a / $b + ($a % $b ? 1 : 0);
}

sub make_common_pages {
  my ($cur, $max) = @_;
  return [
    map {
      active  => $_ != $cur,
      page    => $_,
      visible =>
    }, 1 .. $max
  ];
}

sub calc_visibility {
  my ($cur, $max, $this) = @_;
  any { $_ } abs($cur - $this) < 5,
             $cur <= 3,
             $cur == $max,
             any { ! abs ($cur - $this) % $_ } 10, 50, 100, 500, 1000, 5000;
}

1;

__END__

=encoding utf-8

=head1 NAME

SL::Helper::Paginated - Manager mixin for paginating results.

=head1 SYNOPSIS

In the manager:

  use SL::Helper::Paginated;

  __PACKAGE__->default_objects_per_page(10); # optional, defaults to 20

In the controller:

  my %args = (
    query => [ id         => $params{list_of_selected_ids},
               other_attr => $::form->{other_attr}, ],
  );

  $self->{pages}   = SL::DB::Manager::MyObject->paginate(args => \%args, page => $::form->{page});
  $self->{objects} = SL::DB::Manager::MyObject->get_all(%args);

In the template:

  [% PROCESS 'common/paginate.html'
    pages=SELF.pages
    base_url=L.url_for(action='list', ...)
  %]

=head1 FUNCTIONS

=over 4

=item C<paginate> args => HREF, page => $page, [ per_page => $per_page ]

Paginate will prepare information to be used for paginating, change the given
args to use them, and return a data structure containing information for later
display.

C<args> needs to contain a reference to a hash, which will be used as an
argument for C<get_all>. After C<paginate> the keys C<page> and C<per_page>
will be set. The keys C<limit> and C<offset> will be unset, should they exist,
since they don't make sense with paginating.

C<page> should contain a value between 1 and the maximum pages. Will be
sanitized.

The parameter C<per_page> is optional. If not given the default value of the
Manager will be used.

=back

=head1 TEMPLATE HELPERS

=over 4

=item C<common/paginate.html> pages=SELF.pages, base_url=URL

The template will render a simple list of links to the
various other pages. A C<base_url> must be given for the links to work.

=back

=head1 BUGS

None yet.

=head1 AUTHOR

Sven Schöling E<lt>s.schoeling@linet-services.deE<gt>

=cut
