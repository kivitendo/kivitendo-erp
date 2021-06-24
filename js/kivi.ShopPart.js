namespace('kivi.ShopPart', function(ns) {
  var $dialog;

  ns.shop_part_dialog = function(title, html) {
    var id            = 'jqueryui_popup_dialog';
    var dialog_params = {
      id:     id,
      width:  800,
      height: 500,
      modal:  true,
      close: function(event, ui) { $dialog.remove(); },
    };

    $('#' + id).remove();

    $dialog = $('<div style="display:none" id="' + id + '"></div>').appendTo('body');
    $dialog.attr('title', title);
    $dialog.html(html);
    $dialog.dialog(dialog_params);

    $('.cancel').click(ns.close_dialog);

    return true;
  };

  ns.close_dialog = function() {
    $dialog.dialog("close");
  }

  ns.save_shop_part = function(shop_part_id) {
    var form = $('form').serializeArray();
    form.push( { name: 'action', value: 'ShopPart/update' }
             , { name: 'shop_part_id',  value: shop_part_id }
    );

    $.post('controller.pl', form, function(data) {
      kivi.eval_json_result(data);
    });
  }

  ns.add_shop_part = function(part_id,shop_id) {
    var form = $('form').serializeArray();
    form.push( { name: 'action', value: 'ShopPart/update' }
    );
    $.post('controller.pl', form, function(data) {
      kivi.eval_json_result(data);
    });
  }

  ns.edit_shop_part = function(shop_part_id) {
    $.post('controller.pl', { action: 'ShopPart/create_or_edit_popup', shop_part_id: shop_part_id }, function(data) {
      kivi.eval_json_result(data);
    });
  }

  ns.create_shop_part = function(part_id, shop_id) {
    $.post('controller.pl', { action: 'ShopPart/create_or_edit_popup', part_id: part_id, shop_id: shop_id }, function(data) {
      kivi.eval_json_result(data);
    });
  }

  ns.get_all_categories = function(shop_part_id) {
    $.post('controller.pl', { action: 'ShopPart/get_categories', shop_part_id: shop_part_id }, function(data) {
      kivi.eval_json_result(data);
    });
  }

  ns.save_categories = function(shop_part_id, shop_id) {
    var form = $('form').serializeArray();
    form.push( { name: 'action', value: 'ShopPart/save_categories' }
             , { name: 'shop_id', value: shop_id }
             , { name: 'shop_part_id', value: shop_part_id }
    );

    $.post('controller.pl', form, function(data) {
      kivi.eval_json_result(data);
    });
  }

  ns.update_shop_part = function(shop_part_id) {
    $.post('controller.pl', { action: 'ShopPart/update_shop', shop_part_id: shop_part_id }, function(data) {
      kivi.eval_json_result(data);
    });
  }

  ns.update_discount_source = function(row, source, discount_str) {
    $('#active_discount_source_' + row).val(source);
    if (discount_str) $('#discount_' + row).val(discount_str);
    $('#update_button').click();
  }

  ns.show_images = function(id) {
    var url = 'controller.pl?action=ShopPart/show_files&id='+id;
    $('#shop_images').load(url);
  }

  ns.update_price_n_price_source = function(shop_part_id,price_source) {
    $.post('controller.pl', { action: 'ShopPart/show_price_n_pricesource', shop_part_id: shop_part_id, pricesource: price_source }, function(data) {
      kivi.eval_json_result(data);
    });
  }

  ns.update_stock = function(shop_part_id) {
    $.post('controller.pl', { action: 'ShopPart/show_stock', shop_part_id: shop_part_id }, function(data) {
      kivi.eval_json_result(data);
    });
  }

  ns.massUploadInitialize = function() {
    kivi.popup_dialog({
      id: 'status_mass_upload',
      dialog: {
        title: kivi.t8('Status Shopupload')
      }
    });
  };

  ns.massUploadStarted = function() {
    $('#status_mass_upload').data('timerId', setInterval(function() {
      $.get("controller.pl", {
        action: 'ShopPart/upload_status',
        job_id: $('#smu_job_id').val()
      }, kivi.eval_json_result);
    }, 5000));
  };

  ns.massUploadFinished = function() {
    clearInterval($('#status_mass_upload').data('timerId'));
    $('.ui-dialog-titlebar button.ui-dialog-titlebar-close').prop('disabled', '')
  };

  ns.imageUpload = function(id,type,filetype,upload_title,gl) {
    kivi.popup_dialog({ url:     'controller.pl',
                        data:    { action: 'File/ajax_upload',
                                   file_type:   filetype,
                                   object_type: type,
                                   object_id:   id,
                                   is_global:   gl
                                 },
                        id:     'files_upload',
                        dialog: { title: kivi.t8('File upload'), width: 650, height: 240 } });
    return true;
  }


  ns.setup = function() {
    kivi.ShopPart.massUploadInitialize();
    kivi.submit_ajax_form('controller.pl?action=ShopPart/mass_upload','[name=shop_parts]');
  };

});
