/*
	Some scripts for the HTML Output. To be used in conjunction with `../lib/webpreview.sh`.
	
	In Flux: http://macromates.com/wiki/Suggestions/StylingHTMLOutput
*/
function selectTheme(event) {
	var theme = event.target.value;
	var title = event.target.options[event.target.options.selectedIndex].title;

	TextMate.system("defaults write com.macromates.textmate.webpreview SelectedTheme '" + theme + "'", null);

	document.getElementById('tm_webpreview_body').className = theme;
	document.getElementById('tm_webpreview_content').className = theme;
	
	var replacements = {teaser: "teaser", gradient: "header"};
	for(var r in replacements) {
		var element = document.getElementById(r);
		element.src = 'file://' + title + theme + '/images/' + replacements[r] + ".png";
	}
}

function hide_header() {
	document.getElementById('tm_webpreview_header').style.display = 'none';
	document.getElementById('tm_webpreview_content').setAttribute('style', 'margin-top: 1em');
	// var header = document.getElementById('tm_webpreview_header');
	// var parent = header.parentNode;
	// parent.removeChild(header);
}
