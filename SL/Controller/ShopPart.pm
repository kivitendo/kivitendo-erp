package SL::Controller::ShopPart;

use strict;

use parent qw(SL::Controller::Base);

use SL::BackgroundJob::ShopPartMassUpload;
use SL::System::TaskServer;
use Data::Dumper;
use SL::Locale::String qw(t8);
use SL::DB::ShopPart;
use SL::DB::Shop;
use SL::DB::File;
use SL::DB::ShopImage;
use SL::DB::Default;
use SL::Helper::Flash;
use SL::Controller::Helper::ParseFilter;
use MIME::Base64;

use Rose::Object::MakeMethods::Generic
(
   scalar                 => [ qw(price_sources) ],
  'scalar --get_set_init' => [ qw(shop_part file shops) ],
);

__PACKAGE__->run_before('check_auth');
__PACKAGE__->run_before('add_javascripts', only => [ qw(edit_popup list_articles) ]);
__PACKAGE__->run_before('load_pricesources',    only => [ qw(create_or_edit_popup) ]);

#
# actions
#

sub action_create_or_edit_popup {
  my ($self) = @_;

  $self->render_shop_part_edit_dialog();
}

sub action_update_shop {
  my ($self, %params) = @_;

  my $shop_part = SL::DB::Manager::ShopPart->find_by(id => $::form->{shop_part_id});
  die unless $shop_part;

  require SL::Shop;
  my $shop = SL::Shop->new( config => $shop_part->shop );

  my $connect = $shop->check_connectivity;
  if($connect->{success}){
    my $return    = $shop->connector->update_part($self->shop_part, 'all');

    # the connector deals with parsing/result verification, just needs to return success or failure
    if ( $return == 1 ) {
      my $now = DateTime->now;
      my $attributes->{last_update} = $now;
      $self->shop_part->assign_attributes(%{ $attributes });
      $self->shop_part->save;
      $self->js->html('#shop_part_last_update_' . $shop_part->id, $now->to_kivitendo('precision' => 'minute'))
             ->flash('info', t8("Updated part [#1] in shop [#2] at #3", $shop_part->part->displayable_name, $shop_part->shop->description, $now->to_kivitendo('precision' => 'minute') ) )
             ->render;
    } else {
      $self->js->flash('error', t8('The shop part wasn\'t updated.'))->render;
    }
  }else{
    $self->js->flash('error', t8('The shop part wasn\'t updated. #1', $connect->{data}->{version}))->render;
  }


}

sub action_show_files {
  my ($self) = @_;

  my $images = SL::DB::Manager::ShopImage->get_all( where => [ 'files.object_id' => $::form->{id}, ], with_objects => 'file', sort_by => 'position' );

  $self->render('shop_part/_list_images', { header => 0 }, IMAGES => $images);
}

sub action_ajax_delete_file {
  my ( $self ) = @_;
  $self->file->delete;

  $self->js
    ->run('kivi.ShopPart.show_images',$self->file->object_id)
    ->render();
}

sub action_get_shop_parts {
  my ( $self ) = @_;
  $main::lxdebug->dump(0, "TST: ShopPart get_shop_parts form", $::form);
  my $parts_fetched;
  my $new_parts;

  my $type = $::form->{type};
  if ( $type eq "get_one" ) {
    my $shop_id = $::form->{shop_id};
    my $part_number = $::form->{part_number};

    if ( $shop_id && $part_number ) {
      my $shop_config = SL::DB::Manager::Shop->get_first(query => [ id => $shop_id, obsolete => 0 ]);
      my $shop = SL::Shop->new( config => $shop_config );
      unless ( SL::DB::Manager::Part->get_all_count( query => [ partnumber => $part_number ] )) {
        $new_parts = $shop->connector->get_shop_parts($part_number);
        push @{ $parts_fetched }, $new_parts ;
      } else {
        flash_later('error', t8('From shop "#1" :  Number: #2 #3 ', $shop->config->description, $part_number, t8('Partnumber is already exist')));
      }
    } else {
        flash_later('error', t8('Shop or partnumber not selected.'));
    }
  } elsif ( $type eq "get_new" ) {
    my $active_shops = SL::DB::Manager::Shop->get_all(query => [ obsolete => 0 ]);
    foreach my $shop_config ( @{ $active_shops } ) {
      my $shop = SL::Shop->new( config => $shop_config );

      $new_parts = $shop->connector->get_shop_parts;
      push @{ $parts_fetched }, $new_parts ;
    }
  }

  foreach my $shop_fetched(@{ $parts_fetched }) {
    if($shop_fetched->{error}){
      flash_later('error', t8('From shop "#1" :  #2 ', $shop_fetched->{shop_description}, $shop_fetched->{message},));
    }else{
      flash_later('info', t8('From shop #1 :  #2 parts have been imported.', $shop_fetched->{description}, $shop_fetched->{number_of_parts},));
    }
  }

  $self->redirect_to(controller => "ShopPart", action => 'list_articles');
}

sub action_get_categories {
  my ($self) = @_;

  require SL::Shop;
  my $shop = SL::Shop->new( config => $self->shop_part->shop );

  my $connect = $shop->check_connectivity;
  if($connect->{success}){
    my $categories = $shop->connector->get_categories;

    $self->js
      ->run(
        'kivi.ShopPart.shop_part_dialog',
        t8('Shopcategories'),
        $self->render('shop_part/categories', { output => 0 }, CATEGORIES => $categories )
      )
      ->reinit_widgets;
      $self->js->render;
  }else{
    $self->js->flash('error', t8('Can\'t connect to shop. #1', $connect->{data}->{version}))->render;
  }

}

sub action_show_price_n_pricesource {
  my ($self) = @_;

  my ( $price, $price_src_str ) = $self->get_price_n_pricesource($::form->{pricesource});

  if( $price_src_str eq 'sellprice'){
    $price_src_str = t8('Sellprice');
  }elsif( $price_src_str eq 'listprice'){
    $price_src_str = t8('Listprice');
  }elsif( $price_src_str eq 'lastcost'){
    $price_src_str = t8('Lastcost');
  }
  $self->js->html('#price_' . $self->shop_part->id, $::form->format_amount(\%::myconfig,$price,2))
           ->html('#active_price_source_' . $self->shop_part->id, $price_src_str)
           ->render;
}

sub action_show_stock {
  my ($self) = @_;
  my ( $stock_local, $stock_onlineshop, $active_online );

  require SL::Shop;
  my $shop = SL::Shop->new( config => $self->shop_part->shop );

  if($self->shop_part->last_update) {
    my $shop_article = $shop->connector->get_article_info($self->shop_part->part->partnumber);
    $stock_onlineshop = $shop_article->{data}->{mainDetail}->{inStock};
    $active_online = $shop_article->{data}->{active};
  }

  $stock_local = $self->shop_part->part->onhand;

  $self->js->html('#stock_' . $self->shop_part->id, $::form->format_amount(\%::myconfig,$stock_local,0)."/".$::form->format_amount(\%::myconfig,$stock_onlineshop,0))
           ->html('#toogle_' . $self->shop_part->id,$active_online)
           ->render;
}

sub action_get_n_write_categories {
  my ($self) = @_;

  my @shop_parts =  @{ $::form->{shop_parts_ids} || [] };
  foreach my $part(@shop_parts){

    my $shop_part = SL::DB::Manager::ShopPart->get_all( where => [id => $part], with_objects => ['part', 'shop'])->[0];
    require SL::DB::Shop;
    my $shop = SL::Shop->new( config => $shop_part->shop );
    my $online_article = $shop->connector->get_article_info($shop_part->part->partnumber);
    my $online_cat = $online_article->{data}->{categories};
    my @cat = ();
    for(keys %$online_cat){
      my @cattmp;
      push @cattmp,$online_cat->{$_}->{id};
      push @cattmp,$online_cat->{$_}->{name};
      push @cat,\@cattmp;
    }
    my $attributes->{shop_category} = \@cat;
    my $active->{active} = $online_article->{data}->{active};
    $shop_part->assign_attributes(%{$attributes}, %{$active});
    $shop_part->save;
  }
  $self->redirect_to( action => 'list_articles' );
}

sub action_save_categories {
  my ($self) = @_;

  my @categories =  @{ $::form->{categories} || [] };

    my @cat = ();
    foreach my $cat ( @categories) {
      my @cattmp;
      push( @cattmp,$cat );
      push( @cattmp,$::form->{"cat_id_${cat}"} );
      push( @cat,\@cattmp );
    }

  my $categories->{shop_category} = \@cat;

  my $params = delete($::form->{shop_part}) || { };

  $self->shop_part->assign_attributes(%{ $params });
  $self->shop_part->assign_attributes(%{ $categories });

  $self->shop_part->save;

  flash('info', t8('The categories has been saved.'));

  $self->js->run('kivi.ShopPart.close_dialog')
           ->flash('info', t8("Updated categories"))
           ->render;
}

sub action_reorder {
  my ($self) = @_;
  require SL::DB::ShopImage;
  SL::DB::ShopImage->reorder_list(@{ $::form->{image_id} || [] });

  $self->render(\'', { type => 'json' });
}

sub action_list_articles {
  my ($self) = @_;

  my %filter      = ($::form->{filter} ? parse_filter($::form->{filter}) : query => [ 'shop.obsolete' => 0 ]);
  my $sort_by     = $::form->{sort_by} ? $::form->{sort_by} : 'part.partnumber';
  $sort_by .=$::form->{sort_dir} ? ' DESC' : ' ASC';

  my $articles = SL::DB::Manager::ShopPart->get_all( %filter ,with_objects => [ 'part','shop' ], sort_by => $sort_by );

  foreach my $article (@{ $articles}) {
    my $images = SL::DB::Manager::ShopImage->get_all_count( where => [ 'files.object_id' => $article->part->id, ], with_objects => 'file', sort_by => 'position' );
    $article->{images} = $images;
  }

  $self->_setup_list_action_bar;

  $self->render('shop_part/_list_articles', title => t8('Webshops articles'), SHOP_PARTS => $articles);
}

sub action_upload_status {
  my ($self) = @_;
  my $job     = SL::DB::BackgroundJob->new(id => $::form->{job_id})->load;
  my $html    = $self->render('shop_part/_upload_status', { output => 0 }, job => $job);

  $self->js->html('#status_mass_upload', $html);
  $self->js->run('kivi.ShopPart.massUploadFinished') if $job->data_as_hash->{status} == SL::BackgroundJob::ShopPartMassUpload->DONE();
  $self->js->render;
}

sub action_mass_upload {
  my ($self) = @_;

  my @shop_parts =  @{ $::form->{shop_parts_ids} || [] };

  my $job = SL::DB::BackgroundJob->new(
        type                 => 'once',
        active               => 1,
        package_name         => 'ShopPartMassUpload',
        )->set_data(
        shop_part_record_ids => [ @shop_parts ],
        todo                 => $::form->{upload_todo},
        status               => SL::BackgroundJob::ShopPartMassUpload->WAITING_FOR_EXECUTION(),
        conversation         => [ ],
        num_uploaded         => 0,
   )->update_next_run_at;

   SL::System::TaskServer->new->wake_up;

   my $html = $self->render('shop_part/_upload_status', { output => 0 }, job => $job);

   $self->js
      ->html('#status_mass_upload', $html)
      ->run('kivi.ShopPart.massUploadStarted')
      ->render;
}

sub action_update {
  my ($self) = @_;

  $self->create_or_update;
}

sub render_shop_part_edit_dialog {
  my ($self) = @_;

  $self->js
    ->run(
      'kivi.ShopPart.shop_part_dialog',
      t8('Shop part'),
      $self->render('shop_part/edit', { output => 0 })
    )
    ->reinit_widgets;

  $self->js->render;
}

sub create_or_update {
  my ($self) = @_;

  my $is_new = !$self->shop_part->id;

  my $params = delete($::form->{shop_part}) || { };

  $self->shop_part->assign_attributes(%{ $params });

  $self->shop_part->save;

  my ( $price, $price_src_str ) = $self->get_price_n_pricesource($self->shop_part->active_price_source);
if(!$is_new){
  flash('info', $is_new ? t8('The shop part has been created.') : t8('The shop part has been saved.'));
  $self->js->html('#shop_part_description_' . $self->shop_part->id, $self->shop_part->shop_description)
           ->html('#shop_part_active_' . $self->shop_part->id, $self->shop_part->active)
           ->html('#price_' . $self->shop_part->id, $::form->format_amount(\%::myconfig,$price,2))
           ->html('#active_price_source_' . $self->shop_part->id, $price_src_str)
           ->run('kivi.ShopPart.close_dialog')
           ->flash('info', t8("Updated shop part"))
           ->render;
         }else{
    $self->redirect_to(controller => 'Part', action => 'edit', 'part.id' => $self->shop_part->part_id);
  }
}

#
# internal stuff
#
sub add_javascripts  {
  $::request->{layout}->add_javascripts(qw(kivi.ShopPart.js));
}

sub load_pricesources {
  my ($self) = @_;

  my $pricesources;
  push( @{ $pricesources } , { id => "master_data/sellprice", name => t8("Master Data")." - ".t8("Sellprice") },
                             { id => "master_data/listprice", name => t8("Master Data")." - ".t8("Listprice") },
                             { id => "master_data/lastcost",  name => t8("Master Data")." - ".t8("Lastcost") }
                             );
  my $pricegroups = SL::DB::Manager::Pricegroup->get_all;
  foreach my $pg ( @$pricegroups ) {
    push( @{ $pricesources } , { id => "pricegroup/".$pg->id, name => t8("Pricegroup") . " - " . $pg->pricegroup} );
  };

  $self->price_sources( $pricesources );
}

sub get_price_n_pricesource {
  my ($self,$pricesource) = @_;

  my ( $price_src_str, $price_src_id ) = split(/\//,$pricesource);

  require SL::DB::Pricegroup;
  require SL::DB::Part;
  my $price;
  if ($price_src_str eq "master_data") {
    my $part       = SL::DB::Manager::Part->find_by( id => $self->shop_part->part_id );
    $price         = $part->$price_src_id;
    $price_src_str = $price_src_id;
    }else{
    my $part       = SL::DB::Manager::Part->get_all( where => [id => $self->shop_part->part_id, 'prices.'.pricegroup_id => $price_src_id], with_objects => ['prices'],limit => 1)->[0];
    #my $part       = SL::DB::Manager::Part->find_by( id => $self->shop_part->part_id, 'prices.'.pricegroup_id => $price_src_id );
    my $pricegrp   = SL::DB::Manager::Pricegroup->find_by( id => $price_src_id )->pricegroup;
    $price         = $part->prices->[0]->price;
    $price_src_str = $pricegrp;
  }
  return($price,$price_src_str);
}

sub _setup_list_action_bar {
  my ($self) = @_;

  for my $bar ($::request->layout->get('actionbar')) {
    $bar->add(
        action => [
          t8('Search'),
          submit    => [ '#shop_part_filter', { action => "ShopPart/list_articles" } ],
        ],
        action => [
          t8('Get one part'),
          call    => [ 'kivi.ShopPart.get_shop_parts_one_setup' ],
          tooltip => t8('Get one part by partnumber'),
        ],
        action => [
          t8('Get new parts'),
          call    => [ 'kivi.ShopPart.get_shop_parts_new' ],
          tooltip => t8('Get all new parts'),
        ],
    );
  }
}

sub check_auth {
  $::auth->assert('shop_part_edit');
}

sub init_shop_part {
  if ($::form->{shop_part_id}) {
    SL::DB::Manager::ShopPart->find_by(id => $::form->{shop_part_id});
  } else {
    SL::DB::ShopPart->new(shop_id => $::form->{shop_id}, part_id => $::form->{part_id});
  };
}

sub init_file {
  my $file = $::form->{id} ? SL::DB::File->new(id => $::form->{id})->load : SL::DB::File->new;
  return $file;
}

sub init_shops {
  SL::DB::Shop->shops_dd;
}

1;

__END__

=encoding utf-8


=head1 NAME

SL::Controller::ShopPart - Controller for managing ShopParts

=head1 SYNOPSIS

ShopParts are configured in a tab of the corresponding part.

=head1 ACTIONS

=over 4

=item C<action_update_shop>

To be called from the "Update" button of the shoppart, for manually syncing/upload one part with its shop. Calls some ClientJS functions to modifiy original page.

=item C<action_show_files>



=item C<action_ajax_delete_file>



=item C<action_get_categories>



=item C<action_show_price_n_pricesource>



=item C<action_show_stock>



=item C<action_get_n_write_categories>

Can be used to sync the categories of a shoppart with the categories from online.

=item C<action_save_categories>

The ShopwareConnector works with the CategoryID @categories[x][0] in others/new Connectors it must be tested
Each assigned categorie is saved with id,categorie_name an multidimensional array and could be expanded with categoriepath or what is needed

=item C<action_reorder>



=item C<action_upload_status>



=item C<action_mass_upload>



=item C<action_update>



=item C<create_or_update>



=item C<render_shop_part_edit_dialog>

when self->shop_part is called in template, it will be an existing shop_part with id,
or a new shop_part with only part_id and shop_id set

=item C<add_javascripts>


=item C<load_pricesources>

the price sources to use for the article: sellprice, lastcost,
listprice, or one of the pricegroups. It overwrites the default pricesource from the shopconfig.
TODO: implement valid pricerules for the article

=item C<get_price_n_pricesource>


=item C<check_auth>


=item C<init_shop_part>


=item C<init_file>


=item C<init_shops>

data for drop down filter options

=back

=head1 TODO

CheckAuth
Pricesrules, pricessources aren't fully implemented yet.

=head1 AUTHORS

G. Richardson E<lt>information@kivitendo-premium.deE<gt>
W. Hahn E<lt>wh@futureworldsearch.netE<gt>

=cut
