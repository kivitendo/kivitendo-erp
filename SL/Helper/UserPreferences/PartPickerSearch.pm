package SL::Helper::UserPreferences::PartPickerSearch;

use strict;
use parent qw(Rose::Object);

use Carp;
use List::MoreUtils qw(none);

use SL::Helper::UserPreferences;

use Rose::Object::MakeMethods::Generic (
  'scalar --get_set_init' => [ qw(user_prefs) ],
);

sub get_sales_search_customer_partnumber {
  !!$_[0]->user_prefs->get('sales_search_customer_partnumber');
}

sub get_purchase_search_makemodel {
  !!$_[0]->user_prefs->get('purchase_search_makemodel');
}

sub get_all_as_list_default {
  !!$_[0]->user_prefs->get('all_as_list_default', $_[1]);
}

sub store_sales_search_customer_partnumber {
  $_[0]->user_prefs->store('sales_search_customer_partnumber', $_[1]);
}

sub store_purchase_search_makemodel {
  $_[0]->user_prefs->store('purchase_search_makemodel', $_[1]);
}

sub store_all_as_list_default {
  $_[0]->user_prefs->store('all_as_list_default', $_[1]);
}

sub init_user_prefs {
  SL::Helper::UserPreferences->new(
    namespace => $_[0]->namespace,
  )
}

# read only stuff
sub namespace     { 'PartPickerSearch' }
sub version       { 1 }

1;

__END__

=pod

=encoding utf-8

=head1 NAME

SL::Helper::UserPreferences::PartPickerSearch - preferences intended
to store user settings for the behavior of a partpicker search.

=head1 SYNOPSIS

  use SL::Helper::UserPreferences::PartPickerSearch;
  my $prefs = SL::Helper::UserPreferences::PartPickerSearch->new();

  $prefs->store_purchase_search_makemodel(1);
  my $value = $prefs->get_purchase_search_makemodel;

=head1 DESCRIPTION

This module manages storing the settings for the part picker to search for
customer/vendor partnumber in sales/purchase forms (new order controller).

=head1 BUGS

None yet :)

=head1 AUTHOR

Bernd Bleßmann E<lt>bernd@kivitendo-premium.deE<gt>

=cut
