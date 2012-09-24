var vSwitch_Menu = 0;
function Switch_Menu() {
  vSwitch_Menu=!vSwitch_Menu;
  SetMenuFolded(vSwitch_Menu);
  $.cookie('html-menu-folded', vSwitch_Menu);
}
function SetMenuFolded(on) {
  if (on) {
    $('#html-menu').removeClass('folded');
    $('#content').removeClass('folded');
  } else {
    $('#html-menu').addClass('folded');
    $('#content').addClass('folded');
  }
}
$(function(){
  vSwitch_Menu = $.cookie('html-menu-folded');
  SetMenuFolded(vSwitch_Menu);
})
