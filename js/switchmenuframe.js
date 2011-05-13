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
