namespace("kivi.ImageUpload", function(ns) {
  "use strict";

  const MAXSIZE = 15*1024*1024; // 5MB size limit

  let num_images = 0;

  ns.add_files = function(target) {
    let files = [];
    for (var i = 0; i < target.files.length; i++) {
      files.push(target.files.item(i));
    }

    kivi.FileDB.store_image(files[0], files[0].name, () => {
      ns.reload_images();
      target.value = null;
    });
  };

  ns.reload_images = function() {
    kivi.FileDB.retrieve_all((data) => {
      $('#stored-images').empty();
      num_images = data.length;

      data.forEach(ns.create_thumb_row);
      ns.set_image_button_enabled();
    });
  };

  ns.create_thumb_row = function(file)  {
    let URL = window.URL || window.webkitURL;
    let file_url = URL.createObjectURL(file);

    let $row = $("<div>").addClass("row image-upload-row");
    let $button = $("<a>")
      .addClass("btn-floating btn-large waves-effect waves-light red")
      .click((event) => ns.remove_image(event, file.name))
      .append($("<i>delete</i>").addClass("material-icons"));
    $row.append($("<div>").addClass("col s3").append($button));

    let $image = $('<img>').attr("src", file_url).addClass("materialboxed responsive-img");
    $row.append($("<div>").addClass("col s9").append($image));

    $("#stored-images").append($row);
  };

  ns.remove_image = function(event, key) {
    let $row = $(event.target).closest(".image-upload-row");
    kivi.FileDB.delete_key(key, () => {
      $row.remove();
      num_images--;
      ns.set_image_button_enabled();
    });
  };

  ns.set_image_button_enabled = function() {
    $('#upload_images_submit').attr("disabled", num_images == 0 || !$('#object_id').val());
  };


  ns.upload_files = function() {
    let id = $('#object_id').val();
    let type = $('#object_type').val();

    ns.upload_selected_files(id, type, MAXSIZE);
  };

  ns.upload_selected_files = function(id, type, maxsize) {
    $("#upload_modal").modal("open");

    kivi.FileDB.retrieve_all((myfiles) => {
      let filesize  = 0;
      myfiles.forEach(file => {
        filesize  += file.size;
        if (filesize > maxsize) {
          $("#upload_result").html(kivi.t8("filesize too big: ") + filesize+ kivi.t8(" bytes, max=") + maxsize );
          return;
        }

        let data = new FormData();
        data.append("uploadfiles[]", file);
        data.append("action", "File/ajax_files_uploaded");
        data.append("json", "1");
        data.append("object_type", type);
        data.append("object_id", id);
        data.append("file_type", "attachment");

        $("#upload_result").html(kivi.t8("start upload"));

        let xhr = new XMLHttpRequest;
        xhr.open('POST', 'controller.pl', true);
        xhr.success = ns.attSuccess;
        xhr.progress = ns.attProgress;
        xhr.error = ns.attFailed;
        xhr.abort = ns.attCanceled;
        xhr.send(data);
      });
    });
  };

  ns.attProgress = function(event) {
    if (event.lengthComputable) {
      var percentComplete = (event.loaded / event.total) * 100;
      $("#upload_result").html(percentComplete+" % "+ kivi.t8("uploaded"));
    }
  };

  ns.attFailed = function() {
    $('#upload_modal').modal('close');
    $("#upload_result").html(kivi.t8("An error occurred while transferring the file."));
  };

  ns.attCanceled = function() {
    $('#upload_modal').modal('close');
    $("#upload_result").html(kivi.t8("The transfer has been canceled by the user."));
  };

  ns.attSuccess = function() {
    $('#upload_modal').modal('close');
    $("#upload_result").html(kivi.t8("Files have been uploaded successfully."));
  };

  ns.resolve_object = function(event) {
    let obj_type = $('#object_type').val();
    let number   = event.target.value;

    $.ajax({
      url: "controller.pl",
      data: {
        action: "ImageUpload/resolve_object_by_number",
        object_type: obj_type,
        object_number: number
      },
      type: "json",
      success: (json) => {
        if (json.error) {
          $("#object_description").html("");
          $("#object_id").val("");
        } else {
          $("#object_description").html(json.description);
          $("#object_id").val(json.id);
        }
        ns.set_image_button_enabled();
      },
      error: () => {
        $("#object_description").html("");
        $("#object_id").val("");
        ns.set_image_button_enabled();
      }
    });
  };

  ns.init = function() {
    ns.reload_images();
  };
});

$(kivi.ImageUpload.init);
