/* This is used in bin/mozilla/kopf.pl to switch the HTML side menu on/off
   2010, Sven Donath, lxo@dexo.de  */

var vSwitch_Menu = 1;
var FrameSize = (parent.document.getElementById('menuframe').cols);

function Switch_Menu()
{
    if (vSwitch_Menu)
    {
        vSwitch_Menu=false;
                parent.document.getElementById('menuframe').setAttribute('cols','30,*');
    }
    else
    {
        vSwitch_Menu=true;
                parent.document.getElementById('menuframe').setAttribute('cols',FrameSize);
    }
    return;
}
