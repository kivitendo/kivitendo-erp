namespace("kivi.ImageUpload", function(ns) {
  "use strict";

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
      data.forEach(ns.create_thumb_row);
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
    });
  };

  ns.upload_selected_files = function(id,type,filetype,maxsize) {
    kivi.FileDB.retrieve_all((myfiles) => {
      let filesize  = 0;
      myfiles.forEach(file => {
        filesize  += file.size;
        if (filesize > maxsize) {
          $("#upload_result").html(kivi.t8("filesize too big: ") + filesize+ kivi.t8(" bytes, max=") + maxsize );
          return;
        }

        let data = new FormData();
        data.append(file);
        data.append("action", "File/ajax_files_uploaded");
        data.append("json", "1");
        data.append("object_type", type);
        data.append("object_id", id);
        data.append("file_type", filetype);

        $("#upload_result").html(kivi.t8("start upload"));

        $.ajax({
          url: "controller.pl",
          data: data,
          success: ns.attSuccess,
          progress: ns.attProgress,
          error: ns.attFailes,
          abort: ns.attCanceled
        });
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

  ns.init = function() {
    ns.reload_images();
  };


});

$(kivi.ImageUpload.init);
