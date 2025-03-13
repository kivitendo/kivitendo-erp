package SL::Controller::Shop;

use strict;

use parent qw(SL::Controller::Base);

use SL::Helper::Flash;
use SL::Locale::String;
use SL::DB::Default;
use SL::DB::Manager::Shop;
use SL::DB::Pricegroup;
use SL::DB::TaxZone;

use Rose::Object::MakeMethods::Generic (
  scalar                  => [ qw(connectors price_types price_sources taxzone_id protocols) ],
  'scalar --get_set_init' => [ qw(shop) ]
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('load_types',    only => [ qw(new edit) ]);

#
# actions
#

sub action_list {
  my ($self) = @_;

  $self->_setup_list_action_bar;
  $self->render('shops/list',
                title => t8('Shops'),
                SHOPS => SL::DB::Manager::Shop->get_all_sorted,
               );
}

sub action_edit {
  my ($self) = @_;

  my $is_new = !$self->shop->id;
  $self->_setup_form_action_bar;
  $self->render('shops/form', title => ($is_new ? t8('Add shop') : t8('Edit shop')));
}

sub action_save {
  my ($self) = @_;

  $self->create_or_update;
}

sub action_delete {
  my ($self) = @_;

  if ( eval { $self->shop->delete; 1; } ) {
    flash_later('info',  $::locale->text('The shop has been deleted.'));
  } else {
    flash_later('error', $::locale->text('The shop is in use and cannot be deleted.'));
  };
  $self->redirect_to(action => 'list');
}

sub action_reorder {
  my ($self) = @_;

  SL::DB::Shop->reorder_list(@{ $::form->{shop_id} || [] });
  $self->render(\'', { type => 'json' }); # ' emacs happy again
}

sub action_check_connectivity {
  my ($self) = @_;

  my $ok = 0;
  require SL::Shop;
  my $shop = SL::Shop->new( config => $self->shop );
  my $connect = $shop->check_connectivity;
  $ok       = $connect->{success};
  my  $version = $connect->{data}->{version};
  $self->render('shops/test_shop_connection', { layout => 0 },
                title   => t8('Shop Connection Test'),
                ok      => $ok,
                version => $version);
}

sub check_auth {
  $::auth->assert('config');
}

sub init_shop {
  SL::DB::Manager::Shop->find_by_or_create(id => $::form->{id} || 0)->assign_attributes(%{ $::form->{shop} });
}

#
# helpers
#

sub create_or_update {
  my ($self) = @_;

  my $is_new = !$self->shop->id;

  my @errors = $self->shop->validate;
  if (@errors) {
    flash('error', $_) for @errors;
    $self->load_types();
    $self->action_edit();
    return;
  }

  $self->shop->save;

  flash_later('info', $is_new ? t8('The shop has been created.') : t8('The shop has been saved.'));
  $self->redirect_to(action => 'list');
}

sub load_types {
  my ($self) = @_;
  # data for the dropdowns when editing Shop configs

  require SL::ShopConnector::ALL;
  $self->connectors(SL::ShopConnector::ALL->connectors);

  $self->price_types( [ { id => "brutto", name => t8('brutto') },
                        { id => "netto",  name => t8('netto')  } ] );

  $self->protocols(   [ { id => "http",  name => t8('http') },
                        { id => "https", name => t8('https') } ] );

  my $pricesources;
  push(@{ $pricesources } , { id => "master_data/sellprice", name => t8("Master Data") . " - " . t8("Sellprice") },
                            { id => "master_data/listprice", name => t8("Master Data") . " - " . t8("Listprice") },
                            { id => "master_data/lastcost",  name => t8("Master Data") . " - " . t8("Lastcost")  });
  my $pricegroups = SL::DB::Manager::Pricegroup->get_all;
  foreach my $pg ( @$pricegroups ) {
    push( @{ $pricesources } , { id => "pricegroup/" . $pg->id, name => t8("Pricegroup") . " - " . $pg->pricegroup} );
  };

  $self->price_sources($pricesources);

  #Buchungsgruppen for calculate the tax for an article
  my $taxkey_ids;
  my $taxzones = SL::DB::Manager::TaxZone->get_all_sorted();

  foreach my $tz (@$taxzones) {
    push  @{ $taxkey_ids }, { id => $tz->id, name => $tz->description };
  }
  $self->taxzone_id( $taxkey_ids );
};

sub _setup_form_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      combobox => [
        action => [
          t8('Save'),
          submit    => [ '#form', { action => "Shop/save" } ],
          accesskey => 'enter',
        ],
         action => [
          t8('Delete'),
          submit => [ '#form', { action => "Shop/delete" } ],
        ],
      ],
      action => [
        t8('Check Api'),
        call => [ 'kivi.Shop.check_connectivity', id => "form" ],
        tooltip => t8('Check connectivity'),
      ],
      action => [
        t8('Cancel'),
        submit => [ '#form', { action => "Shop/list" } ],
      ],
    );
  }
}

sub _setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
      link => [
        t8('Add'),
        link => $self->url_for(action => 'edit'),
      ],
    )
  };
}

1;

__END__

=encoding utf-8

=head1 NAME

  SL::Controller::Shop

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 BUGS

None yet. :)

=head1 AUTHOR

G. Richardson E<lt>information@kivitendo-premium.deE<gt>
W. Hahn E<lt>wh@futureworldsearch.netE<gt>
