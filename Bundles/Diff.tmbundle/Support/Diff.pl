#!/usr/bin/perl

# (c) 2005, Eric Hsu

# To Do
# what's with the 'no ending Newline'?
# Allow merging?
# Allow swapping of old and new 
# Allow last diff (if no SELECTED_FILES)
# Allow hiding of common (use CSS)

# Stylesheet switching from http://old.alistapart.com/stories/alternate/

my $css = $ENV{'TM_BUNDLE_SUPPORT'};

my $html = <<END;
<html><head>
<link rel="stylesheet" type="text/css" href="file://$css/diff.css" />
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=utf-8">
END

# $html .= <<END;
# <link rel="stylesheet" type="text/css" href="file://$css/diff-norm.css" title="diff-norm" />
# <link rel="stylesheet" type="text/css" href="file://$css/both-show.css" title="both-show" />
# <link rel="alternate stylesheet" type="text/css" href="file://$css/both-hide.css" title="both-hide" />
# <link rel="alternate stylesheet" type="text/css" href="file://$css/diff-rev.css" title="diff-rev" />
# <script type="text/javascript" src="file://$css/styleswitcher.js"></script>
# END

$html .= '</head><body><tt>';

my $files = $ENV{'TM_SELECTED_FILES'};
$diffout = `diff -s -U99999 $files 2> /dev/null`;

$diffout =~ s/\n\\ No newline at end of file\n/\n/g;

( $OLD1, $OLD2, $NEW1, $NEW2 ) =
  ( $files =~ /\'(.*?)([^\\])\'\s+\'(.*?)([^\\])\'/ );
$OLD = $OLD1 . $OLD2;
$NEW = $NEW1 . $NEW2;

$diffout =~ s/\n\@.*?\n/\n\n/;

# use HTML::Entities;
# encode_entities($diffout);
$diffout =~ s/&/&amp;/g; # silly; make sure this comes before the next two.
$diffout =~ s/</&lt;/g;
$diffout =~ s/>/&gt;/g;

$oldline = $newline = -2;

foreach ( split( /\n/, $diffout ) ) {
    $TMURL = "<a href=\"txmt:\/\/open?url=file:\/\/";
	if ($newline==0 && !$hr_yet) {
		$hr_yet=1;
		$html.=optionlinks() . "<hr>" ;
	}

    if (/^\-/) {
	    s/^\-(.*)$/<span class="old">$1<\/span>/g;
        $oldline++;
        $TMURL .= $OLD;
        $TMURL .= "&amp;line=" . $oldline if ( $oldline > 0 );
    }
    elsif (/^\+/) {
	    s/^\+(.*)$/<span class="new">$1<\/span>/g;
        $newline++;
        $TMURL .= $NEW;
        $TMURL .= "&amp;line=" . $newline if ( $newline > 0 );

    }
    else {    # this is common text. By default, we jump to the new version.
	    s/^(.*?)$/<span class="both">$1<\/span>/g;
        $newline++;
        $oldline++;

        $TMURL .= $NEW;
        $TMURL .= "&amp;line=" . $newline if ( $newline > 0 );
    }

    $html .= $TMURL . '">' . $_ . "</a>" . "<br>";
}

$html .= "</tt></body></html>\n";

print $html;

sub unquote {
    my $in = shift;
    $in =~ s/^'//;
    s/'$//;
    return $in;
}

sub optionlinks {
# 	return <<END;
# Common Text: <a href="#" onclick="setActiveStyleSheet('both-hide');return false;">Hide</a>
# <a href="#" onclick="setActiveStyleSheet('both-show');return false;">Show</a>
# END
}
