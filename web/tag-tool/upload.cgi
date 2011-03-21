#!/usr/bin/perl -w

use strict;

# Perl version
require 5.0; 

# Dependencies
use CGI;
use CGI::Carp;
use File::Basename;

# Maximum file size
$CGI::POST_MAX = 1024 * 5000;
# We don't accept "anything"
my $safe_filename_characters = "a-zA-Z0-9_.-";
# Storage
my $upload_dir = "/home/huydhn/public_html/tagtool/sources";

# Get the uploaded file
my $query = new CGI;  
my $filename = $query->param("text");

# Check the filesize
if ( !$filename )  
{  
	print $query->header();  
	print "There was a problem uploading your file (try a smaller file).";  
	exit;  
}

# Manipulate the filename a bit
my ($name, $path, $extension) = fileparse( $filename, '\..*' );  
$filename = $name . $extension;
# in order to avoid illegal characters
$filename =~ tr/ /_/;
$filename =~ s/[^$safe_filename_characters]//g;

# Get the uploaded file
my $output_filehandle = undef;
my $upload_filehandle = $query->upload("text");
# and save it
open($output_filehandle, ">$upload_dir/$filename") or die "$!";  
binmode $output_filehandle;  
while (<$upload_filehandle>)
{ 
	my $line = $_;
	# Print $_
	print $output_filehandle $line;
}
close($output_filehandle);

# What the heck
print "Content-Type: text/html\n\n";
# Output
Building( $upload_dir . "/" . $filename );

# Support functions
sub Building
{
	my ($uploaded_file) = @_;

	my $input_filehandle = undef;
	# Represent the uploaded file
	open($input_filehandle, "<:utf8", $uploaded_file) or die "$!";
	# Begin document
	print "<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\">", "\n";
	print "<head>", "\n";
	print "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />", "\n";
	print "<title>Text Labeller</title>", "\n";
	print "</head>", "\n";

	# Body 
 	print "<body>", "\n";
	
	# Highlighting
	Select();
	# Floating menu
	FloatingMenu();	
	
	# Get the content 
	my @lines = <$input_filehandle>;
	# Print the tag and the content
	print "<table border=\"1\">", "\n";
	for (my $i = 0; $i < scalar(@lines); $i++)
	{
		print "<tr>", "\n";
		
		my @content = split /\s+\|\|\|\s+/, $lines[ $i ];
		if (scalar(@content) == 2)
		{
			print "<td><div id=\"tag$i\">", $content[ 0 ], "</div></td>", "\n";
			print "<td><div id=\"line$i\">", $content[ 1 ], "</div></td>", "\n";
		}
		else
		{
			print "<td><div id=\"tag$i\">", "&nbsp;&nbsp;", "</div></td>", "\n";
			print "<td><div id=\"line$i\">", $lines[ $i ], "</div></td>", "\n";
		}

		print "</tr>", "\n";
	}
	print "</table>", "\n";

	# Print the labeller
	print "<div id=\"floatdiv\" style=\"position:absolute; width:300px;height:40px;top:10px;right:10px; padding:16px;background:#FFFFFF; border:2px solid #2266AA; z-index:100\">", "\n";
	print "<center>", "\n";
	print "<select id='tagtype'>", "\n";
	
	print "<option selected value='unknown'>unknown</option>", "\n";
	print "<option value=\"address\">address</option>", "\n";
	print "<option value=\"affiliation\">affiliation</option>", "\n";
	print "<option value=\"author\">author</option>", "\n";
	print "<option value=\"bodyText\">bodyText</option>", "\n";
	print "<option value=\"category\">category</option>", "\n";
	print "<option value=\"construct\">construct</option>", "\n";
	print "<option value=\"copyright\">copyright</option>", "\n";
	print "<option value=\"email\">email</option>", "\n";
	print "<option value=\"equation\">equation</option>", "\n";
	print "<option value=\"figure\">figure</option>", "\n";
	print "<option value=\"figureCaption\">figureCaption</option>", "\n";
	print "<option value=\"footnote\">footnote</option>", "\n";
	print "<option value=\"keyword\">keyword</option>", "\n";
	print "<option value=\"listItem\">listItem</option>", "\n";
	print "<option value=\"note\">note</option>", "\n";
	print "<option value=\"page\">page</option>", "\n";
	print "<option value=\"reference\">reference</option>", "\n";
	print "<option value=\"sectionHeader\">sectionHeader</option>", "\n";
	print "<option value=\"subsectionHeader\">subsectionHeader</option>", "\n";
	print "<option value=\"subsubsectionHeader\">subsubsectionHeader</option>", "\n";
	print "<option value=\"table\">table</option>", "\n";
	print "<option value=\"tableCaption\">tableCaption</option>", "\n";
	print "<option value=\"title\">title</option>", "\n";

	print "</select>", "\n";
	print "<input type=\"button\" value=\"Tag\" onclick=\"surroundRange()\">", "\n";
	print "</center>", "\n";
    print "</div>","\n";	

	# End body
	print "</body>", "\n";
	# End of all evil
	print "</html>", "\n";

	close($input_filehandle);
}

# Support functions
sub SaveAs
{
print <<SAVEAS;
SAVEAS
}

# Support functions
sub Select
{
print <<SELECT;
<script type="text/javascript" src="rangy-1.1/rangy-core.js"></script>
<script language=javascript>
function getFirstRange()
{
	var sel = rangy.getSelection();
	return sel.rangeCount ? sel.getRangeAt(0) : null;
}
function getFirstContainer()
{
	var sel = rangy.getSelection();	
	var range = sel.rangeCount ? sel.getRangeAt(0) : null;
	var node = range.startContainer;
	return range ? range.startContainer : null;
}
function getLastContainer()
{
	var sel = rangy.getSelection();	
	var range = sel.rangeCount ? sel.getRangeAt(0) : null;
	return range ? range.endContainer : null;
}
function surroundRange() 
{	
	var snode = getFirstContainer();
	var enode = getLastContainer();

	var range = rangy.createRange();
	range.setStart(snode);
	range.setEndAfter(enode);

	if (range) 
	{
		var el = document.createElement("span");
		el.style.backgroundColor = "yellow";
		try
		{
			range.surroundContents(el);
		} 
		catch(ex) 
		{
			if ((ex instanceof rangy.RangeException || Object.prototype.toString.call(ex) == "[object RangeException]") && ex.code == 1) 
			{
				alert("Unable to surround range because range partially selects a non-text node. See DOM Level 2 Range spec for more information.\\n\\n" + ex);
				return;
			}
			else
			{
				alert("Unexpected errror: " + ex);
				return;
			}
		}
	}

	var selected_type = document.getElementById("tagtype").value;

	var parent = snode.parentNode;
	var parent_id = parent.id;

	var tag_id = parent_id.replace("line", "tag");
	var tag_node = document.getElementById(tag_id);
	
	if (tag_node)
	{
		tag_node.firstChild.nodeValue = selected_type;
		tag_node.setAttribute("tagged", "yes");
	}
	else
	{
		return;	
	}

	var current = tag_id.substring(3);
	for (var i = current - 1; i >= 0; i--)
	{
		tag_id = "tag" + i;
		tag_node = document.getElementById(tag_id);

		var tagged = tag_node.getAttribute("tagged");
		// Already tagged
		if (tagged)
		{
			break;	
		}
		else
		{
			tag_node.firstChild.nodeValue = selected_type;
			tag_node.setAttribute("tagged", "yes");		
		}
	}
}
</script>
SELECT
}

# Support functions
sub FloatingMenu
{
print "<script type=\"text/javascript\" src=\"floating.js\">", "</script>", "\n";
print <<FLOATING;
<script type="text/javascript">  
	floatingMenu.add('floatdiv',
	{
		// Represents distance from left or right browser window
		// border depending upon property used. Only one should be
		// specified.
		// targetLeft: 0,
		targetRight: 10,
		
		// Represents distance from top or bottom browser window
		// border depending upon property used. Only one should be
		// specified.
		targetTop: 10,
		// targetBottom: 0,
		
		// Uncomment one of those if you need centering on
		// X- or Y- axis.
		// centerX: true,
		// centerY: true,
		
		// Remove this one if you don't want snap effect
		snap: true
	});
</script>
FLOATING
}




