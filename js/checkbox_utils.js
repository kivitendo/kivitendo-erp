function checkbox_check_all(cb_name, prefix, start, end) {
  var i;

  var control = document.getElementsByName(cb_name)[0];
  if (!control)
    return;

  var checked = control.checked;

  for (i = start; i <= end; i++) {
    control = document.getElementsByName(prefix + i)[0];
    if (control)
      control.checked = checked;
  }
}
