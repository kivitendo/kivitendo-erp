var vSwitch_Menu = 1;
function Switch_Menu() {
  vSwitch_Menu=!vSwitch_Menu;
  SetMenuFolded(vSwitch_Menu);
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
  SetMenuFolded(vSwitch_Menu);
})
