namespace('kivi.File', function(ns) {

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

  ns.upload_selected_files = function(id,type,filetype,maxsize,is_global) {
      var myform = document.getElementById("upload_form");
      var filesize  = 0;
      var myfiles = document.getElementById("upload_files").files;
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

      myform.action ="controller.pl?action=File/ajax_files_uploaded&json=1&object_type="+
          type+'&object_id='+id+'&file_type='+filetype+'&is_global='+is_global;
      var oReq = new XMLHttpRequest();
      oReq.onload            = ns.attSuccess;
      oReq.upload.onprogress = ns.attProgress;
      oReq.upload.onerror    = ns.attFailed;
      oReq.upload.onabort    = ns.attCanceled;
      oReq.open("post",myform.action, true);
      $("#upload_result").html(kivi.t8("start upload"));
      oReq.send(new FormData(myform));
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

  ns.init = function() {
  }

});
