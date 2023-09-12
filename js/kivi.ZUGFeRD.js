namespace('kivi.ZUGFeRD', function(ns) {
  ns.update_file_name = function() {
    let file = document.getElementById("file").files[0];
    if (file) {
      document.getElementById("file_name").value = file.name;
    }
  };
});
