namespace('kivi.File', function(ns) {
  ns.list_div_id = undefined;

  ns.rename = function(id,type,file_type,checkbox_class,is_global) {
    var $dlg       = $('#rename_dialog_'+file_type);
    var parent_id  = $dlg.parent("div.ui-tabs-panel").attr('id');
    var checkboxes = $('.'+checkbox_class).filter(function () { return  $(this).prop('checked'); });

    if (checkboxes.size() === 0) {
      alert(kivi.t8("No file selected, please set one checkbox!"));
      return false;
    }
    if (checkboxes.size() > 1) {
      alert(kivi.t8("More than one file selected, please set only one checkbox!"));
      return false;
    }
    var file_id = checkboxes[0].value;
    $('#newfilename_id_'+file_type).val($('#filename_'+file_id).text());
    $('#next_ids_id_'+file_type).val('');
    $('#is_global_id_'+file_type).val(is_global);
    $('#rename_id_id_'+file_type).val(file_id);
    $('#sessionfile_id_'+file_type).val('');
    $('#rename_extra_text_'+file_type).html('');
    kivi.popup_dialog({
                      id:     'rename_dialog_'+file_type,
                      dialog: { title: kivi.t8("Rename attachment")
                               , width:  400
                               , height: 200
                               , modal:  true
                               , close: function() {
                                 $dlg.remove().appendTo('#' + parent_id);
                               }
                              }
    });
    return true;
  }

  ns.renameclose = function(file_type) {
    $("#rename_dialog_"+file_type).dialog('close');
    return false;
  }

  ns.renameaction = function(file_type) {
    $("#rename_dialog_"+file_type).dialog('close');
    var data = {
      action:          'File/ajax_rename',
      id:              $('#rename_id_id_'+file_type).val(),
      to:              $('#newfilename_id_'+file_type).val(),
      next_ids:        $('#next_ids_id_'+file_type).val(),
      is_global:       $('#is_global_id_'+file_type).val(),
      sessionfile:     $('#sessionfile_id_'+file_type).val(),
    };
    $.post("controller.pl", data, kivi.eval_json_result);
    return true;
  }

  ns.askForRename = function(file_id,file_type,file_name,sessionfile,next_ids,is_global) {
    $('#newfilename_id_'+file_type).val(file_name);
    $('#rename_id_id_'+file_type).val(file_id);
    $('#is_global_id_'+file_type).val(is_global);
    $('#next_ids_id_'+file_type).val(next_ids);
    $('#sessionfile_id_'+file_type).val(sessionfile);
    $('#rename_extra_text_'+file_type).html(kivi.t8("The uploaded filename still exists.<br>If you not modify the name this is a new version of the file"));
    var $dlg       = $('#rename_dialog_'+file_type);
    var parent_id  = $dlg.parent("div.ui-tabs-panel").attr('id');
    kivi.popup_dialog(
      {
        id:     'rename_dialog_'+file_type,
        dialog: { title: kivi.t8("Rename attachment")
                  , width:  400
                  , height: 200
                  , modal:  true
                  , close: function() {
                    $dlg.remove().appendTo('#' + parent_id);
                  } }
      }
    );
  }

  ns.upload = function(id,type,filetype,upload_title,gl) {
    $('#upload_status_dialog').remove();

    kivi.popup_dialog({ url:     'controller.pl',
                        data:    { action: 'File/ajax_upload',
                                   file_type:   filetype,
                                   object_type: type,
                                   object_id:   id,
                                   is_global:   gl
                                 },
                        id:     'files_upload',
                        dialog: { title: upload_title, width: 650, height: 240 } });
    return true;
  }

  ns.reset_upload_form = function() {
      $('#attachment_updfile').val('');
      $("#upload_result").html('');
      ns.allow_upload_submit();
  }

  ns.allow_upload_submit = function() {
      $('#upload_selected_button').prop('disabled',$('#upload_files').val() === '');
  }

  ns.upload_status_dialog = function() {
    $('#files_upload').remove();
    $('#upload_status_dialog').remove();

    var html  = '<div id="upload_status_dialog"><p><div id="upload_result"></div></p>';
    html      = html + '<p><input type="button" value="' + kivi.t8('close') + '" size="30" onclick="$(\'#upload_status_dialog\').dialog(\'close\');">';
    html      = html + '</p></div>';
    $(html).hide().appendTo('#' + ns.list_div_id);

    kivi.popup_dialog({id: 'upload_status_dialog',
                       dialog: {title:  kivi.t8('Upload Status'),
                                height: 200,
                                width:  650 }});
  };

  ns.upload_selected_files = function(id,type,filetype,maxsize,is_global) {
      var myform = document.getElementById("upload_form");
      var myfiles = document.getElementById("upload_files").files;

      ns.upload_files(id, type, filetype, maxsize,is_global, myfiles, myform);
  }

  ns.upload_files = function(id, type, filetype, maxsize, is_global, myfiles, myform) {
      var filesize  = 0;
      for ( i=0; i < myfiles.length; i++ ) {
          var fname ='';
          try {
              filesize  += myfiles[i].size;
              fname = encodeURIComponent(myfiles[i].name);
          }
          catch(err) {
              fname ='';
              try {
                  fname = myfiles[i].name;
              }
              catch(err2) { fname ='';}
              $("#upload_result").html(kivi.t8("filename has not uploadable characters ")+fname);
              return;
          }
      }
      if ( filesize > maxsize ) {
          $("#upload_result").html(kivi.t8("filesize too big: ")+
                                   filesize+ kivi.t8(" bytes, max=") + maxsize );
          return;
      }

      var fd = new FormData(myform);
      if (!myform) {
        $(myfiles).each(function(idx, elt) {
          fd.append('uploadfiles[+]', elt);
        });
      }
      fd.append('action',      'File/ajax_files_uploaded');
      fd.append('json',        1);
      fd.append('object_type', type);
      fd.append('object_id',   id);
      fd.append('file_type',   filetype);
      fd.append('is_global',   is_global);

      var oReq = new XMLHttpRequest();
      oReq.onload            = ns.attSuccess;
      oReq.upload.onprogress = ns.attProgress;
      oReq.upload.onerror    = ns.attFailed;
      oReq.upload.onabort    = ns.attCanceled;
      oReq.open("post", 'controller.pl', true);
      $("#upload_result").html(kivi.t8("start upload"));
      oReq.send(fd);
  }

  ns.attProgress = function(oEvent) {
      if (oEvent.lengthComputable) {
          var percentComplete = (oEvent.loaded / oEvent.total) * 100;
          $("#upload_result").html(percentComplete+" % "+ kivi.t8("uploaded"));
      }
  }

  ns.attFailed = function(evt) {
      $('#files_upload').dialog('close');
      $("#upload_result").html(kivi.t8("An error occurred while transferring the file."));
  }

  ns.attCanceled = function(evt) {
      $('#files_upload').dialog('close');
      $("#upload_result").html(kivi.t8("The transfer has been canceled by the user."));
  }

  ns.attSuccess = function() {
      $('#upload_status_dialog').dialog('close');
      $('#files_upload').dialog('close');
      kivi.eval_json_result(jQuery.parseJSON(this.response));
  }

  ns.delete = function(id,type,file_type,checkbox_class,is_global) {
    var checkboxes = $('.'+checkbox_class).filter(function () { return  $(this).prop('checked'); });

    if ((checkboxes.size() === 0) ||
        !confirm(kivi.t8('Do you really want to delete the selected documents?')))
      return false;
    var data = {
      action     :  'File/ajax_delete',
      object_id  :  id,
      object_type:  type,
      file_type  :  file_type,
      ids        :  checkbox_class,
      is_global  :  is_global,
    };
    $.post("controller.pl?" + checkboxes.serialize(), data, kivi.eval_json_result);
    return false;
  }

  ns.delete_file = function(id,controller_action) {
    $.post('controller.pl', { action: controller_action, id: id }, function(data) {
      kivi.eval_json_result(data);
    });
  };

  ns.unimport = function(id,type,file_type,checkbox_class) {
    var checkboxes = $('.'+checkbox_class).filter(function () { return  $(this).prop('checked'); });

    if ((checkboxes.size() === 0) ||
        !confirm(kivi.t8('Do you really want to unimport the selected documents?')))
      return false;
    var data = {
      action     :  'File/ajax_unimport',
      object_id  :  id,
      object_type:  type,
      file_type  :  file_type,
      ids        :  checkbox_class,
    };
    $.post("controller.pl?" + checkboxes.serialize(), data, kivi.eval_json_result);
    return false;
  }

  ns.update = function(id,type,file_type,is_global) {
    var data = {
      action:       'File/list',
      json:         1,
      object_type:  type,
      object_id:    id,
      file_type:    file_type,
      is_global:    is_global
    };

    $.post("controller.pl", data, kivi.eval_json_result);
    return false;
  }

  ns.import = function (id,type,file_type,fromwhere,frompath) {
    kivi.popup_dialog({ url:     'controller.pl',
                        data:    { action      : 'File/ajax_importdialog',
                                   object_type : type,
                                   source      : fromwhere,
                                   path        : frompath,
                                   file_type   : file_type,
                                   object_id   : id
                                 },
                        id:     'import_dialog',
                        dialog: { title: kivi.t8('Import documents from #1',[fromwhere]), width: 420, height: 540 }
                      });
    return true;
  }

  ns.importclose = function() {
    $("#import_dialog").dialog('close');
    return false;
  }

  ns.importaction = function(id,type,file_type,fromwhere,frompath,checkbox_class) {
    var checkboxes = $('.'+checkbox_class).filter(function () { return  $(this).prop('checked'); });

    $("#import_dialog").dialog('close');
    if (checkboxes.size() === 0) {
      return false;
    }
    var data = {
        action     : 'File/ajax_import',
        object_id  : id,
        object_type: type,
        file_type  : file_type,
        source     : fromwhere,
        path       : frompath,
        ids        : checkbox_class
    };
    $.post("controller.pl?" + checkboxes.serialize(), data, kivi.eval_json_result);
    return true;
  }

  ns.downloadOrderitemsFiles = function(type,id) {
    var data = {
      action:       'DownloadZip/download_orderitems_files',
      object_type:  type,
      object_id:    id,
      element_type: 'part',
      zipname:      'Order_Files_'+id,
    };
    $.download("controller.pl", data);
    return false;
  }

  ns.add_enlarged_thumbnail = function(e) {
    var file_id        = $(e.target).data('file-id');
    var file_version   = $(e.target).data('file-version');
    var overlay_img_id = 'enlarged_thumb_' + file_id;
    if (file_version) { overlay_img_id = overlay_img_id + '_' + file_version };
    var overlay_img    = $('#' + overlay_img_id);

    if (overlay_img.data('is-overlay-shown') == 1) return;

    $('.thumbnail').off('mouseover');
    overlay_img.data('is-overlay-shown', 1);
    overlay_img.show();

    if (overlay_img.data('is-overlay-loaded') == 1) return;

    var data = {
      action:         'File/ajax_get_thumbnail',
      file_id:        file_id,
      file_version:   file_version,
      size:           512
    };

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.remove_enlarged_thumbnail = function(e) {
    $(e.target).hide();
    $(e.target).data('is-overlay-shown', 0);
    $('.thumbnail').on('mouseover', ns.add_enlarged_thumbnail);
  };

  ns.init = function() {
    // Preventing page from redirecting
    $("#" + ns.list_div_id).on("dragover", function(e) {
      e.preventDefault();
      e.stopPropagation();
    });

    $("#" + ns.list_div_id).on("drop", function(e) {
      e.preventDefault();
      e.stopPropagation();
    });

    // Drag enter
    $('.upload_drop_zone').on('dragenter', function (e) {
      e.stopPropagation();
      e.preventDefault();
    });

    // Drag over
    $('.upload_drop_zone').on('dragover', function (e) {
      e.stopPropagation();
      e.preventDefault();
    });

    // Drop
    $('.upload_drop_zone').on('drop', function (e) {
      e.stopPropagation();
      e.preventDefault();

      ns.upload_status_dialog();

      var object_type = $(e.target).data('object-type');
      var object_id   = $(e.target).data('object-id');
      var file_type   = $(e.target).data('file-type');
      var is_global   = $(e.target).data('is-global');
      var maxsize     = $(e.target).data('maxsize');
      var files       = e.originalEvent.dataTransfer.files;
      ns.upload_files(object_id, object_type, file_type, maxsize, is_global, files);
    });

    $('.thumbnail').on('mouseover', ns.add_enlarged_thumbnail);
    $('.overlay_img').on('click', ns.remove_enlarged_thumbnail);
    $('.overlay_img').on('mouseout', ns.remove_enlarged_thumbnail);
  };

});
