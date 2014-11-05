[% USE LxERP %][% USE JavaScript %]
function insert_selected_predefined_text() {
  var data = {
[%- FOREACH pt = SELF.predefined_texts %]
    [% JavaScript.escape(pt.id) %]: {
      title: "[% JavaScript.escape(pt.title) %]",
      text: "[% JavaScript.escape(pt.text) %]"
    }[% UNLESS loop.last %],[% END %]
[% END %]
  }

  var id = $('#[% id_base %]_predefined_text_block').val();
  var pt = data[id];
  if (!pt)
    return false;

  var title_ctrl = $('#[% id_base %][% title_ctrl_id %]');

  if (   ((pt.title || '') != '')
      && (   ((title_ctrl.val() || '') == '')
          || confirm('[%- LxERP.t8("Do you want to overwrite your current title?") %]')))
    title_ctrl.val(pt.title);

  if ((pt.text || '') != '')
    $('#[% id_base %][% text_ctrl_id %]').ckeditorGet().insertHtml(pt.text);

  return false;
}
