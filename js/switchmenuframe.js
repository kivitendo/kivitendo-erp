var vSwitch_Menu = 1;
var Frame;
var FrameSize;

function Switch_Menu() {
  if (Frame) {
    Frame.attr('cols',vSwitch_Menu ? '30,*' : FrameSize);
    vSwitch_Menu=!vSwitch_Menu;
  }
}

$(function(){
  Frame = $(parent.document.getElementById('menuframe'));
  FrameSize = Frame.attr('cols');
})
