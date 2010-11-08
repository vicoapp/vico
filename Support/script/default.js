/*

Default JavaScript for HTML output. _UNDER CONSTRUCTION - PLEASE DON'T TINKER YET_
By Sune Foldager.

*/

function showElement(id)
{
   var b = document.getElementById(id + "_b");
   var s = document.getElementById(id + "_s");
   var h = document.getElementById(id + "_h");
   b.style.display = "block";
   s.style.display = "none";
   h.style.display = "inline";
}

function hideElement(id)
{
   var b = document.getElementById(id + "_b");
   var s = document.getElementById(id + "_s");
   var h = document.getElementById(id + "_h");
   b.style.display = "none";
   s.style.display = "inline";
   h.style.display = "none";
}

function clearElement(id)
{
	document.getElementById(id).innerHTML = ""
}
