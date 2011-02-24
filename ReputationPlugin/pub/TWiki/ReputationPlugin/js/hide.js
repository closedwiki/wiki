/*modified version of http://www.netlobo.com/media/examples/offleftdivhide.html*/

function toggleDivOL( elemID )
{
    var elem = document.getElementById( elemID );
    if( elem.style.position != 'relative' )
    {
        elem.style.position = 'relative';
        elem.style.left = '0px';
    }
    else
    {
        elem.style.position = 'absolute';
        elem.style.left = '-4000px';
    }
}
