package SL::DB::Helper::CustomerVendorLink;

use strict;
use Exporter ();

use constant CUSTOMER_CLASS  => 'SL::DB::Customer';
use constant CUSTOMER_ID_COL => 'customer_id';
use constant VENDOR_CLASS    => 'SL::DB::Vendor';
use constant VENDOR_ID_COL   => 'vendor_id';

use constant SYNCEE          => '__linked_customer_vendor_syncee';

sub import {
  my ($class, %params) = @_;

  die "mode needs to be customer or vendor" unless $params{mode} =~ /^(customer|vendor)$/;

  my $caller_package = caller;

  make_linked_customer_vendor($caller_package, $params{mode});
  make_unlink_customer_vendor($caller_package, $params{mode});
  make_sync_customer_vendor($caller_package, $params{mode});

  $caller_package->before_save(sub { auto_sync($_[0]); 1; });
}

sub make_unlink_customer_vendor {
  my ($caller_package, $mode) = @_;
  my $unlink_cv = sub {
    $_[0]->linked_customer_vendor_rel([]);
  };

  if ($mode eq 'customer') {
    no strict 'refs';
    *{ $caller_package . '::unlink_vendor' } = $unlink_cv;
  } else {
    no strict 'refs';
    *{ $caller_package . '::unlink_customer' } = $unlink_cv;
  }
}

sub make_linked_customer_vendor {
  my ($caller_package, $mode) = @_;
  my $linked_cv = sub {
    _linked_customer_vendor(@_);
  };

  if ($mode eq 'customer') {
    my $linked_cv_cached = sub {
      _linked_customer_vendor_cached(CUSTOMER_CLASS, CUSTOMER_ID_COL, VENDOR_CLASS, VENDOR_ID_COL, @_);
    };

    no strict 'refs';
    *{ $caller_package . '::linked_vendor' }                 = $linked_cv;
    *{ $caller_package . '::linked_vendor_cached' }          = $linked_cv_cached;

    *{ $caller_package . '::linked_customer_vendor' }        = $linked_cv;
    *{ $caller_package . '::linked_customer_vendor_cached' } = $linked_cv_cached;
  } else {
    my $linked_cv_cached = sub {
      _linked_customer_vendor_cached(VENDOR_CLASS, VENDOR_ID_COL, CUSTOMER_CLASS, CUSTOMER_ID_COL, @_);
    };

    no strict 'refs';
    *{ $caller_package . '::linked_customer' }               = $linked_cv;
    *{ $caller_package . '::linked_customer_cached' }        = $linked_cv_cached;

    *{ $caller_package . '::linked_customer_vendor' }        = $linked_cv;
    *{ $caller_package . '::linked_customer_vendor_cached' } = $linked_cv_cached;
  }
}

sub make_sync_customer_vendor {
  my ($caller_package, $mode) = @_;

  no strict 'refs';
  *{ $caller_package . '::sync_linked_customer_vendor' } = sub {
    my ($self, $other) = @_;

    $other //= $self->linked_customer_vendor;

    return unless $other;

    $other->assign_attributes($_ => $self->$_) for qw(name taxzone_id currency_id obsolete);
  };
}

sub _linked_customer_vendor {
  my ($self, $new_other) = @_;
  # rose can only do mapping tables for many-to-many relations, but linked customer/vendors are one-to-one ensured in the database, so downcast those here
  # fortunately many-to-many relationships are symmetric so we can use the same code in both customer/vendor to get/set the respective other

  if (@_ > 1) {
    $self->linked_customer_vendor_rel([ grep defined, $new_other ]);
  }

  return unless $self->linked_customer_vendor_rel;
  $self->linked_customer_vendor_rel->[0];
}

sub _linked_customer_vendor_cached {
  my ($our_class, $our_id, $other_class, $other_id, $self, $new_other) = @_;
  # same as above, but make sure to an existing object that was already loaded with _cached to not break transactions that deal with lots of customers and vendors

  if (@_ > 5) {
    if ($new_other) {
      if (ref $new_other) {
        $new_other->cache;
      } else {
        $new_other = $other_class->load_cached($new_other);
      }
    }
    $self->linked_customer_vendor_rel([ grep defined, $new_other ]);
    return $new_other;
  }

  # get mapping object
  my $link = SL::DB::CustomerVendorLink->load_cached($self->id);

  my @others;

  if ($link) {
    return $other_class->load_cached($link->$other_id);
  } else {
    return $self->linked_customer_vendor_rel->[0];
  }
}

sub _linked_customer_vendor_id {
  my ($other_class, $self, $new_other_id) = @_;


  my $new_other = $other_class->new(id => $new_other_id)->load;
  my $cur_other = $self->linked_customer_vendor_rel->[0];

  # set and unset only if this would change anything
  # don't trigger relationship updates without need

  if (!$new_other && $cur_other) {
    $self->linked_customer_vendor_rel([]);
  }

  if ($new_other && (!$cur_other || ($cur_other && $new_other->id == $new_other->id))) {
    $self->linked_customer_vendor_rel([ $new_other ]);
  }
}

sub auto_sync {
  my ($self) = @_;

  return if $self->{SYNCEE};

  my ($other) = $self->linked_customer_vendor_rel;
  return unless $other;

  $self->sync_linked_customer_vendor($other);
  $other->{SYNCEE} = 1;
}


1;

__END__

=encoding utf-8

=head1 NAME

SL::DB::Helper::CustomerVendorLink - mixin for linked customer/vendors

=head1 SYNOPSIS

  # in SL::DB::Customer/Vendor:
  use SL::DB::Helper::CustomerVendorLink;

  # add the underlying mapping many-to-many relation
  __PACKAGE__->meta->add_relationship(
    linked_customer_vendor_rel => {
      type       => 'many to many',
      map_class  => 'SL::DB::CustomerVendorLink',
    },
  );


  # later use methods on Customer/Vendor:

  my $v = SL::DB::Vendor->new(...);
  my $c = SL::DB::Customer->new(...);

  my $v = $c->linked_vendor;               # may return undef
  my $c = $v->linked_customer;
  my $v = $c->linked_vendor_cached;        # dito, but uses request cache
  my $c = $v->linked_customer_cached;
  my $vc = $cv->linked_customer_vendor;    # smart accessor
  my $vc = $cv->linked_customer_vendor_cached;

  # all of these are also accessors to set a linked customer/vendor:
  $vendor->linked_customer($customer);
  $vendor->linked_customer_cached($customer);
  $cv->linked_customer_vendor($vc);
  $cv->linked_customer_vendor_cached($vc);

  # manually sync - usually happens on save
  $c->sync_customer_vendor;

  # unlink
  $c->linked_vendor(undef);

=head1 DESCRIPTION

This mixin provides wrapper methods for the linked customer/vendor feature. All
methods designed to be exported into the L<SL::DB::Customer> and
L<SL::DB::Vendor> packages.

In the database, links are modelled with the join table
C<customer_vendor_links>, where both C<customer_id> and C<vendor_id> are
unique. This mixin provides one-to-one accessors for this join table, since
L<Rose::DB> can only model it as many-to-many, and provides an abstraction
over the sync mechanism.

=head1 EXPORTED METHODS

=over 4

=item C<linked_customer_vendor [OBJ]>

=item C<linked_customer [OBJ]>

=item C<linked_vendor [OBJ]>

Main getter/setter for the linked customer or vendor. The reduced spellings are aliases only exported in the respective other class.

If used as a setter, also accepts the id of an existing object instead of the whole object (this is Rose behaviour).

If used as a setter with a modified object, a save will cascade to the other object (also Rose behaviour).


=item C<linked_customer_vendor_cached [OBJ]>

=item C<linked_customer_cached [OBJ]>

=item C<linked_vendor_cached [OBJ]>

Cached version of the main getter/setter. This will prefer cached elements, at the expense of not using the Rose accessor.


=item C<sync_linked_customer_vendor [OBJ]>

Copy synced attributes manually. Usually not needed as the module registers a before_save hook.

=back

=head1 BUGS

None yet. :)

=head1 AUTHOR

Sven Schöling $<lt>s.schoeling@googlemail.comE<gt>

=cut
