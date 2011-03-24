#!/usr/bin/perl -wT

# Author: Do Hoang Nhat Huy <huydo@comp.nus.edu.sg>
# Modified from template by Min-Yen Kan <kanmy@comp.nus.edu.sg>

require 5.0;
use strict;

# Dependencies
use FindBin;
use Getopt::Long;
use HTML::Entities;

# I do not know a better solution to find a lib path in -T mode.
# So if you know a better solution, I'd be glad to hear.
# See this http://www.perlmonks.org/?node_id=585299 for why I used the below code

# To get correct path in case 2 scripts in different directories use FindBin
FindBin::again(); 
my $path = undef;
BEGIN 
{
	if ($FindBin::Bin =~ /(.*)/) { $path = $1; }
}
use lib "$path/../../lib";

# Local libraries
use SectLabel::PreProcess;

### USER customizable section
$0 =~ /([^\/]+)$/; my $progname = $1;
my $version = "1.0";
### END user customizable section

sub License 
{
	print STDERR "# Copyright 2011 \251 by Do Hoang Nhat Huy\n";
}

sub Help 
{
	print STDERR "Process Omnipage XML output (concatenated results fromm all pages of a PDF file), and extract text lines together with other XML infos\n";
	print STDERR "usage: $progname -h\t[invokes help]\n";
	print STDERR "       $progname -in xmlfile -out outfile [-decode] [-log]\n";
	print STDERR "Options:\n";
	print STDERR "\t-q      \tQuiet Mode (don't echo license)\n";
	print STDERR "\t-decode \tDecode HTML entities and then output, to avoid double entity encoding later\n";
}

my $quite			= 0;
my $help			= 0;
my $out_file		= undef;
my $in_file			= undef;
my $is_decode		= 0;
my $is_debug		= 0;

$help = 1 unless GetOptions(	'in=s' 		=> \$in_file,
								'out=s' 	=> \$out_file,
								'decode' 	=> \$is_decode,
								'log'		=> \$is_debug,
								'h'			=> \$help,
								'q'			=> \$quite	);

if ($help || ! defined $in_file || ! defined $out_file) 
{
	Help();
  	exit(0);
}

if (!$quite) 
{
	License();
}

### Untaint ###
$in_file	 = UntaintPath($in_file);
$out_file	 = UntaintPath($out_file);
$tag_file	 = UntaintPath($tag_file);
$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin';
### End untaint ###

# Mark page, para, line, word
my %g_page_hash = ();

# Mark paragraph
my @g_para = ();

# XML features
# Location feature
my @g_pos_hash	= (); 
my $g_minpos	= 1000000; 
my $g_maxpos	= 0;
# Align feature
my @g_align		= (); 
# Bold feature
my @g_bold		= ();
# Italic feature
my @g_italic	= ();
# Font size feature
my %g_font_size_hash	= (); 
my @g_font_size			= ();
# Font face feature
my %g_font_face_hash	= (); 
my @g_font_face = ();
# Pic feature
my @g_pic	= (); 
# Table feature
my @g_table	= ();
# Bullet feature
my @g_bullet	= ();
# All tags
my %tags = ();

# BEGIN
my $markup_output	= "";
my $all_text		= ProcessFile($in_file, $out_file, \%tags);

# Find header part
my @lines		= split(/\n/, $all_text);
my $num_lines	= scalar(@lines);
my ($header_length, $body_length, $body_start_id) = SectLabel::PreProcess::FindHeaderText(\@lines, 0, $num_lines);

# Done
Output(\@lines, $out_file);
# END

sub ProcessFile 
{
	my ($in_file, $tags) = @_;

	if (! open(IN, "<:utf8", $in_file)) { die "Could not open xml file " . $in_file; }
	my $xml = do { local $/; <IN> };
	close IN;

	###
	# Huydhn
	# NOTE: the omnipage xml is not well constructed (concatenated multiple xml files).
	# This merged xml need to be fixed first before pass it to xml processing libraries, e.g. xml::twig
	###
	# Convert to Unix format
	$xml =~ s/\r//g;
	# Remove <?xml version="1.0" encoding="UTF-8"?>
	$xml =~ s/<\?xml.+?>\n//g;
	# Remove <!--XML document generated using OCR technology from ScanSoft, Inc.-->
	$xml =~ s/<\!\-\-XML.+?>\n//g;
	# Declaration and root
	$xml = "<?xml version=\"1.0\"?>" . "\n" . "<root>" . "\n" . $xml . "\n" . "</root>";

	# New document
	my $doc = new Omni::Omnidoc();
	$doc->set_raw($xml);

	# All the line 
	my @line_pos	 = ();
	my @line_content = ();

	# Current position	
	my %current		 = ();

	# All pages in the document
	my $pages = $doc->get_objs_ref();

	# From page, To page
	my $start_page	= 0;
	my $end_page	= scalar(@{ $pages }) - 1;

	# Tree traveling is 'not' fun. Seriously.
	# This is like a dungeon seige.
	for (my $x = $start_page; $x <= $end_page; $x++)	
	{
		# Current position
		$current{ 'L1' } = $x;

		# Column or dd
		my $level_2	 =	$pages->[ $x ]->get_objs_ref();
		my $start_l2 =	0;
		my $end_l2	 =	scalar(@{ $level_2 }) - 1;

		for (my $y = $start_l2; $y <= $end_l2; $y++)
		{
			# Thang's code
			# Thang considers <dd> tag as image, I just follow that
			if ($level_2->[ $z ]->get_name() eq $obj_list->{ 'OMNIDD' })
			{
				$is_pic = 1;	
			}
			else
			{
				$is_pic = 0;				
			}
			# End Thang's code

			# Current position
			$current{ 'L2' } = $y;

			# Table or paragraph
			my $level_3	 = 	$level_2->[ $y ]->get_objs_ref();
			my $start_l3 =	0;
			my $end_l3	 =	scalar(@{ $level_3 }) - 1;

			for (my $z = $start_l3; $z <= $end_l3; $z++)
			{
				# Current position
				$current{ 'L3' } = $z;

				# Is a paragraph
				if ($level_3->[ $z ]->get_name() eq $obj_list->{ 'OMNIPARA' })
				{
					# Thang's code
					ProcessPara($level_3->[ $z ], $is_pic);
					# End Thang's code
				}
				# Is a table or frame
				elsif (($level_3->[ $z ]->get_name() eq $obj_list->{ 'OMNITABLE' }) || ($level_3->[ $z ]->get_name() eq $obj_list->{ 'OMNIFRAME' }))
				{
					# TODO: this actually a trick to get it working for now.
					# We care not about the cell inside the table but the content
					# of the table only. So the table is consider a paragraph in
					# which lines are its row
					my @level_4 = split(/\n/, $level_3->[ $z ]->get_content());
				
					for (my $t = 0; $t <= scalar(@level_4); $t++)
					{
						# Current position
						$current{ 'L4' } = $t;

						# Only keep non-empty line
						my $l	=	$level_4[ $t ];
						$l		=~	s/^\s+|\s+$//g;

						if ($l ne "")
						{
							# Save the current position and the content of the current line
							push @line_pos, { %current };
							push @line_content, $level_4[ $t ];
						}
					}
				}


			}
		}
	}

  	my $is_para		= 0;
	my $is_table	= 0;
	my $is_space	= 0;
  	my $is_pic		= 0;
  	my $line_id		= 0;
  	my $all_text	= "";
  	my $text		= "";

  	return $all_text;
}

sub Output 
{
	my ($lines, $out_file) = @_;
	open(OF, ">:utf8", "$out_file") || die"#Can't open file \"$out_file\"\n";

	####### Final output ############
  	# XML feature label
	my %g_font_size_labels = (); 
	# my %g_space_labels = (); # yes, no

  	if($is_xml_feature) 
	{
		GetFontSizeLabels(\%g_font_size_hash, \%g_font_size_labels);
		# GetSpaceLabels(\%g_space_hash, \%g_space_labels);
  	}

  	my $id				= -1;
  	my $output			= "";
 	my $para_line_id	= -1;
  	my $para_line_count	= 0;

	foreach my $line (@{$lines}) 
	{
    	$id++;

		# Remove ^M character at the end of each line if any
		$line =~ s/\cM$//; 
	
		# Empty lines
    	if($line =~ /^\s*$/)
		{      
			if(!$is_allow_empty) 
			{ 
				next; 
			} 
			else 
			{
				if($is_debug) { print STDERR "#! Line $id empty!\n"; }
      		}
    	} 

    	if ($g_para[$id] eq "yes")
		{
			# Mark para
      		if($output ne "")
			{
				if($is_para_delimiter)
				{
	  				print OF "# Para $para_line_id $para_line_count\n$output";
	  				$para_line_count = 0;
				} 
				else 
				{
	  				if ($is_decode) { $output = decode_entities($output); }
					print OF $output;
				}

				$output = "";
      		}
      
	  		$para_line_id = $id;
		}
    
    	$output .= $line;
    	$para_line_count++;

    	# Output XML features
		if ($is_xml_feature)
		{
      		# Loc feature
			my $loc_feature;
      		if ($g_pos_hash[$id] != -1)
			{
				$loc_feature = "xmlLoc_".int(($g_pos_hash[$id] - $g_minpos)*8.0/($g_maxpos - $g_minpos + 1));
      		}
 
		 	# Align feature
      		my $align_feature = "xmlAlign_" . $g_align[$id];

			# Font_size feature
      		my $font_size_feature;
			if ($g_font_size[$id] == -1)
			{
				$font_size_feature = "xmlFontSize_none";
			} 
			else 
			{
				$font_size_feature = "xmlFontSize_" . $g_font_size_labels{$g_font_size[$id]};
			}

      		my $bold_feature	= "xmlBold_"	. $g_bold[$id]; 	# Bold feature
      		my $italic_feature	= "xmlItalic_"	. $g_italic[$id]; 	# Italic feature
      		my $pic_feature		= "xmlPic_"		. $g_pic[$id]; 		# Pic feature
      		my $table_feature	= "xmlTable_"	. $g_table[$id]; 	# Table feature
      		my $bullet_feature	= "xmlBullet_"	. $g_bullet[$id]; 	# Bullet feature

			# Space feature
			# my $space_feature;
			# if($g_space[$id] eq "none")
			# {
			#	$space_feature = "xmlSpace_none";
			# } 
			# else 
			# {
			#	$space_feature = "xmlSpace_" . $g_space_labels{$g_space[$id]};
			# }

      		# Differential features
			my ($align_diff, $font_size_diff, $font_face_diff, $font_sf_diff, $font_sfbi_diff, $font_sfbia_diff, $para_diff) = GetDifferentialFeatures($id);

      		# Each line and its XML features
			$output .= " |XML| $loc_feature $bold_feature $italic_feature $font_size_feature $pic_feature $table_feature $bullet_feature $font_sfbia_diff $para_diff\n"; 
		} 
		else 
		{
      		$output .= "\n";
    	}
  	}

	# Mark para
	if ($output ne "")
	{
    	if ($is_para_delimiter)
		{
      		print OF "# Para $para_line_id $para_line_count\n$output";
      		$para_line_count = 0;
    	}
		else 
		{
      		if($is_decode){ $output = decode_entities($output); }
			print OF $output;
    	}
    	$output = ""
  	}
  
  	close OF;
}

sub GetDifferentialFeatures 
{
	my ($id) = @_;

	# AlignChange feature
  	my $align_diff = "bi_xmlA_";

	if ($id == 0)
	{
    	$align_diff .= $g_align[$id];
  	} 
	elsif ($g_align[$id] eq $g_align[$id-1])
	{
    	$align_diff .= "continue";
  	} 
	else 
	{
    	$align_diff .= $g_align[$id];
  	}
  
  	# FontFaceChange feature
	my $font_face_diff = "bi_xmlF_";
  	if ($id == 0)
	{
    	$font_face_diff .= "new";
  	} 
	elsif ($g_font_face[$id] eq $g_font_face[$id-1])
	{
    	$font_face_diff .= "continue";
  	} 
	else 
	{
    	$font_face_diff .= "new";
  	}

	# FontSizeChange feature
  	my $font_size_diff = "bi_xmlS_";
	if ($id == 0)
	{
    	$font_size_diff .= "new";
	} 
	elsif ($g_font_size[$id] == $g_font_size[$id-1])
	{
    	$font_size_diff .= "continue";
  	} 
	else 
	{
    	$font_size_diff .= "new";
  	}  
  
  	# FontSFChange feature
  	my $font_sf_diff = "bi_xmlSF_";
  	if ($id == 0)
	{
    	$font_sf_diff .= "new";
	} 
	elsif ($g_font_size[$id] == $g_font_size[$id-1] && $g_font_face[$id] eq $g_font_face[$id-1])
	{
    	$font_sf_diff .= "continue";
  	} 
	else 
	{
    	$font_sf_diff .= "new";
  	}
  
  	# FontSFBIChange feature
  	my $font_sfbi_diff = "bi_xmlSFBI_";
	if ($id == 0)
	{
    	$font_sfbi_diff .= "new";
  	} 
	elsif ($g_font_size[$id] == $g_font_size[$id-1] && $g_font_face[$id] eq $g_font_face[$id-1] && $g_bold[$id] eq $g_bold[$id-1] && $g_italic[$id] eq $g_italic[$id-1])
	{
    	$font_sfbi_diff .= "continue";
  	} 
	else 
	{
    	$font_sfbi_diff .= "new";
  	}
  
  	# FontSFBIAChange feature
  	my $font_sfbia_diff = "bi_xmlSFBIA_";
  	if ($id == 0)
	{
    	$font_sfbia_diff .= "new";
  	} 
	elsif ($g_font_size[$id] == $g_font_size[$id-1] && $g_font_face[$id] eq $g_font_face[$id-1] && $g_bold[$id] eq $g_bold[$id-1] && $g_italic[$id] eq $g_italic[$id-1] && $g_align[$id] eq $g_align[$id-1])
	{
    	$font_sfbia_diff .= "continue";
  	} 
	else 
	{
    	$font_sfbia_diff .= "new";
  	}

  	# Para change feature
  	my $para_diff = "bi_xmlPara_";
	# Header part, consider each line as a separate paragraph
  	if ($id < $body_start_id)
	{ 
    	$para_diff .= "header";
  	} 
	else 
	{
    	if($g_para[$id] eq "yes")
		{
      		$para_diff .= "new";
    	} 
		else 
		{
      		$para_diff .= "continue";
    	}
  	}

  	return ($align_diff, $font_size_diff, $font_face_diff, $font_sf_diff, $font_sfbi_diff, $font_sfbia_diff, $para_diff);
}

sub GetFontSizeLabels 
{
 	my ($g_font_size_hash, $g_font_size_labels) = @_;

  	if ($is_debug) { print STDERR "# Map fonts\n"; }
  	my @sorted_fonts = sort { $g_font_size_hash->{$b} <=> $g_font_size_hash->{$a} } keys %{$g_font_size_hash}; # Sort by values, obtain keys
 
	my $common_size = $sorted_fonts[0];
	@sorted_fonts = sort { $a <=> $b } keys %{$g_font_size_hash}; # Sort by keys, obtain keys

	# Index of common font size
	my $common_index = 0; 
	foreach (@sorted_fonts)
	{
		# Found
    	if ($common_size == $_) 
		{
      		last;
    	}
    	$common_index++;
  	}
  
  	# Small fonts
  	for (my $i = 0; $i < $common_index; $i++)
	{
    	$g_font_size_labels->{$sorted_fonts[$i]} = "smaller";
		
		if($is_debug)
		{
      		print STDERR "$sorted_fonts[$i] --> $g_font_size_labels->{$sorted_fonts[$i]}, freq = $g_font_size_hash->{$sorted_fonts[$i]}\n";
    	}
  	}

  	# Common fonts
  	$g_font_size_labels->{$common_size} = "common";
  	if ($is_debug)
	{
    	print STDERR "$sorted_fonts[$common_index] --> $g_font_size_labels->{$sorted_fonts[$common_index]}, freq = $g_font_size_hash->{$sorted_fonts[$common_index]}\n";
  	}		

  	# Large fonts
  	for (my $i = ($common_index + 1); $i < scalar(@sorted_fonts); $i++)
	{ 
    	if ((scalar(@sorted_fonts)-$i) <= 3)
		{
      		$g_font_size_labels->{$sorted_fonts[$i]} = "largest".($i+1-scalar(@sorted_fonts));
    	} 
		else 
		{
      		$g_font_size_labels->{$sorted_fonts[$i]} = "larger";
    	}

    	if($is_debug)
		{	  
      		print STDERR "$sorted_fonts[$i] --> $g_font_size_labels->{$sorted_fonts[$i]}, freq = $g_font_size_hash->{$sorted_fonts[$i]}\n";
    	}
  	}
}

sub GetSpaceLabels 
{
	my ($g_space_hash, $g_space_labels) = @_;

  	if ($is_debug)
	{
    	print STDERR "\n# Map space\n";
  	}
  	my @sorted_spaces = sort { $g_space_hash->{$b} <=> $g_space_hash->{$a} } keys %{$g_space_hash}; # sort by freqs, obtain space faces
  
	my $common_space = $sorted_spaces[0];
  	my $common_freq	 = $g_space_hash->{$common_space};

	# Find similar common freq with larger spaces
  	for (my $i = 0; $i < scalar(@sorted_spaces); $i++)
	{
    	my $freq = $g_space_hash->{$sorted_spaces[$i]};
    	if ($freq/$common_freq > 0.8)
		{
      		if($sorted_spaces[$i] > $common_space)
			{
				$common_space = $sorted_spaces[$i];
      		}
    	} 
		else 
		{
      		last;
    	}
  	}

  	for (my $i = 0; $i < scalar(@sorted_spaces); $i++)
	{
    	if ($sorted_spaces[$i] > $common_space)
		{
      		$g_space_labels->{$sorted_spaces[$i]} = "yes";
    	} 
		else 
		{
      		$g_space_labels->{$sorted_spaces[$i]} = "no";
    	}

    	if($is_debug)
		{
      		print STDERR "$sorted_spaces[$i] --> $g_space_labels->{$sorted_spaces[$i]}, freq = $g_space_hash->{$sorted_spaces[$i]}\n";
    	}
  	}
}

sub GetAttrValue 
{
	my ($attr_text, $attr) = @_;

	my $value = "none";
  	if ($attr_text =~ /^.*$attr=\"(.+?)\".*$/)
	{
    	$value = $1;
  	}
  
  	return $value;
}

sub CheckFontAttr 
{
	my ($attr_text, $attr, $attr_hash, $count) = @_;

  	if ($attr_text =~ /^.*$attr=\"(.+?)\".*$/)
	{
		my $attr_value = $1;
   		$attr_hash->{$attr_value} = $attr_hash->{$attr_value} ? ($attr_hash->{$attr_value} + $count) : $count;
	}
}

sub ProcessTable 
{
	my ($input_text, $is_pic) = @_;

	# For table cell object
	my $is_cell		= 0;

	my $all_text	= "";
	my $text		= ""; 

	my @lines = split(/\n/, $input_text);

	my %table_pos	= (); # $table_pos{$cellText} = "$l-$t-$r-$bottom"
	my %table		= (); # $table{$row}->{$col} = \@para_texts
	my $row_from;   
	my $col_from;
	my $row_till;   
	my $col_till;

	# xml feature
	my $align	= "none"; 
	my $pos		= -1;
	foreach my $line (@lines) 
	{
		if ($line =~ /^<table (.+?)>$/)
		{
			my $attr = $1;
			
			if($is_markup) {	$markup_output .= "### Table $attr\n"; }

			# Fix: wrong regex sequence, huydhn
			#if ($attr =~ /^.*l=\"(\d+)\" t=\"(\d+)\" r=\"(\d+)\" b=\"(\d+)\".*alignment=\"(.+?)\".*$/)
			#{
			#	my ($l, $t, $r, $bottom) = ($1, $2, $3, $4);
			#	$align = $5;

			#	# pos feature
			#	$pos = ($t+$bottom)/2.0;
				
			#	if($pos < $g_minpos) { $g_minpos = $pos; }
			#	if($pos > $g_maxpos) { $g_maxpos = $pos; }
			#} 
			#else 
			#{
			#	print STDERR "# no table alignment or location \"$line\"\n";
			#	$align = "";
			#}

			my ($l, $t, $r, $bottom) = undef;
			if ($attr =~ /^.*l=\"(\d+)\".*$/) { $l = $1; }
			if ($attr =~ /^.*t=\"(\d+)\".*$/) { $t = $1; }
			if ($attr =~ /^.*r=\"(\d+)\".*$/) { $r = $1; }
			if ($attr =~ /^.*b=\"(\d+)\".*$/) { $bottom = $1; }

			if ($t && $bottom)
			{
				# pos feature
				$pos = ($t + $bottom) / 2.0;
				
				if($pos < $g_minpos) { $g_minpos = $pos; }
				if($pos > $g_maxpos) { $g_maxpos = $pos; }
			}
			else
			{
				die "# Undefined table location \"$line\"\n";
			}

			if ($attr =~ /^.*alignment=\"(\d+)\".*$/) 
			{ 
				$align = $1; 
			} 
			else 
			{
				print STDERR "# no table alignment \"$line\"\n";
				$align = "";
			}
			# End.
		}
		elsif ($line =~ /^<cell .*gridColFrom=\"(\d+)\" gridColTill=\"(\d+)\" gridRowFrom=\"(\d+)\" gridRowTill=\"(\d+)\".*>$/) # new cell
		{ 
			$col_from = $1;
			$col_till = $2;
			$row_from = $3;
			$row_till = $4;
			#print STDERR "$row_from $row_till $col_from $col_till\n";
			$is_cell = 1;
		}
		elsif ($line =~ /^<\/cell>$/) # end cell
		{ 
			my @para_texts = ();
			ProcessCell($text, \@para_texts, \%table_pos, $is_pic);
			
			for(my $i = $row_from; $i<=$row_till; $i++)
			{
				for(my $j = $col_from; $j<=$col_till; $j++)
				{
					if(!$table{$i}) { $table{$i} = (); }
					if(!$table{$i}->{$j}) {	$table{$i}->{$j} = (); }

	 				if($i == $row_from && $j == $col_from)
					{
		 				push(@{$table{$i}->{$j}}, @para_texts);
						if(scalar(@para_texts) > 1) { last; }
	 				} 
					else 
					{
		 				push(@{$table{$i}->{$j}}, ""); #add stub "" for spanning rows or cols
	 				}
				}
			}
				
			$is_cell = 0;
			$text = "";
		}    
		elsif($is_cell)
		{
			$text .= $line."\n";
			next;
		}
	}

	# note: such a complicated code is because in the normal node, Omnipage doesn't seem to strictly print column by column given a row is fixed.
	# E.g if col1: paraText1, col2: paraText21\n$paraText22, and col3: paraText31\n$paraText32
	# It will print  paraText1\tparaText21\tparaText31\n\t$paraText22\t$paraText32
	my @sorted_rows = sort {$a <=> $b} keys %table;
	my $is_first_line_para = 1;
	foreach my $row (@sorted_rows)
	{
		my %table_r = %{$table{$row}};
		my @sorted_cols = sort {$a <=> $b} keys %table_r;
		while(1)
		{
			my $is_stop = 1;
			my $row_text = "";

			foreach my $col (@sorted_cols)
			{
				# there's still some thing to process
				if(scalar(@{$table_r{$col}}) > 0)
				{ 
	 				$is_stop = 0;
	 				$row_text .= shift(@{$table_r{$col}});
				}
				$row_text .= "\t";
			}

			if ((!$is_allow_empty && $row_text =~ /^\s*$/) || ($is_allow_empty && $row_text eq ""))
			{
				$is_stop = 1;
			}

			if($is_stop) 
			{
				last;
			} 
			else 
			{
				$row_text =~ s/\t$/\n/;
				$all_text .= $row_text;
				# print STDERR "$row_text";
				
				# para
				if($is_first_line_para)
				{
	 				push(@g_para, "yes");
	 				$is_first_line_para = 0;
				} 
				else 
				{
	 				push(@g_para, "no");
				}

				if($is_xml_feature)
				{
	 				# table feature
	 				push(@g_table, "yes");

	 				# pic feature
	 				if($is_pic)
					{
		 				push(@g_pic, "yes");
	 				} 
					else 
					{
		 				push(@g_pic, "no");
	 				}

	 				push(@g_pos_hash, $pos); # update xml pos value
	 				push(@g_align, $align); # update xml alignment value

	 				### Not assign value ###
					push(@g_font_size, -1); # fontSize feature	  
					push(@g_font_face, "none"); # fontFace feature	  
	 				push(@g_bold, "no"); # bold feature	  
	 				push(@g_italic, "no"); # italic feature
	 				push(@g_bullet, "no"); # bullet feature
					# push(@gSpace, "none"); # space feature
				} # end if xml feature
			}
		}
	}

	return $all_text;
}

sub ProcessCell 
{
	my ($input_text, $para_texts, $table_pos, $is_pic) = @_;

	my $text = ""; 
	my @lines = split(/\n/, $input_text);
	my $is_para = 0;
	my $flag = 0;
	foreach my $line (@lines) 
	{    
		if ($line =~ /^<para (.*)>$/)
		{
			$text .= $line."\n"; # we need the header
			$is_para = 1;

			if($is_markup)
			{
				$markup_output .= "## ParaTable $1\n";
			}
		}
		elsif ($line =~ /^<\/para>$/)
		{
			my ($para_text, $l, $t, $r, $b) = ProcessPara($text, 1, $is_pic);
			my @tokens = split(/\n/, $para_text);

			foreach my $token (@tokens)
			{
				if($token ne "")
				{
	 				push(@{$para_texts}, $token);
	 				$flag = 1;	
				}
			}

			if(!$table_pos->{$para_text})
			{
				$table_pos->{$para_text} = "$l-$t-$r-$b";
			} 
			else 
			{
				#print STDERR "#! Warning: in method processCell, encounter the same para_text $para_text\n";
			}

			$is_para = 0;
			$text = "";
		}
		elsif ($is_para)
		{
			$text .= $line."\n";
			next;
		}
	}
	
	# at least one value should be added for cell which is ""
	if ($flag == 0) 
	{
		push(@{$para_texts}, "");
	}
}

sub ProcessPara 
{
	my ($paragraph, $is_cell, $is_pic) = @_;
 
 	# Paragraph attributes
	my $align	= $paragraph->get_alignment();
	my $space	= $paragraph->get_space_before();
	# Line attributes
  	my ($left, $top, $right, $bottom) = undef;
	# Run attributes	
	my $bold_count		= 0;
  	my $italic_count	= 0;
  	my %font_size_hash	= ();
  	my %font_face_hash	= ();

	# Lines
	my $lines	= $paragraph->get_objs_ref();
	my $start_l	= 0;
	my $end_l	= scalar(@{ $lines }) - 1;

	# Lines
	for (my $t = $start_l; $t <= $end_l; $t++)
	{
		# Line attributes
		$left	= $lines->[ $t ]->get_left_pos();
		$right	= $lines->[ $t ]->get_right_pos();
		$top	= $lines->[ $t ]->get_top_pos();
		$bottom	= $lines->[ $t ]->get_bottom_pos();

		# Runs
		my $runs	= $lines->[ $t ]->get_objs_ref();
		my $start_r	= 0;
		my $end_r	= scalar(@{ $runs }) - 1;

		# Total number of words in a line
		my $words_count = 0;

		for (my $u = $start_r; $u <= $end_r; $u++)
		{
			my $words = $runs->[ $u ]->get_objs_ref();	

			# Update the number of words
			$words_count += scalar(@words);

			# XML format
			my $font_size					= $runs->[ $u ]->get_font_size();
			$font_size_hash{ $font_size }	= $font_size_hash{ $font_size } ? $font_size_hash{ $font_size } + scalar(@words) : scalar(@words); 
			# XML format
			my $font_face 					= $runs->[ $u ]->get_font_face();
			$font_face_hash{ $font_face }	= $font_face_hash{ $font_face } ? $font_face_hash{ $font_face } + scalar(@words) : scalar(@words); 
			# XML format
			if ($runs->[ $u ]->get_bold() eq "true") { $bold_count += scalar(@words); } 
			# XML format
			if ($runs->[ $u ]->get_italic() eq "true") { $italic_count += scalar(@words); } 
		}
			
		# Line attributes - relative position in paragraph
		if (! $is_cell)
		{
			if ($t == $start_l)
			{
 				push @g_para, "yes";
			} 
			else 
			{
 				push @g_para, "no";
	 		}
		}
		
		# Line attributes - line position
		if (! $is_cell)
		{
			my $pos = ($top + $bottom) / 2.0;
			# Compare to global min and max position
			if ($pos < $g_minpos) { $g_minpos = $pos; }
			if ($pos > $g_maxpos) { $g_maxpos = $pos; }
			# Pos feature
			push @g_pos_hash, $pos;
			# Alignment feature
	  		push @g_align, $align;
			# Table feature
			push @g_table, "no";

			if ($is_pic)
			{
	    		push @g_pic, "yes";
	   	 		# Not assign value if line is in image area
	    		push @g_bold, "no";		
	    		push @g_italic, "no";
	    		push @g_bullet, "no";
	    		push @g_font_size, -1; 		
	    		push @g_font_face, "none";
	  		} 
			else 
			{
	    		push @g_pic, "no";
   				UpdateXMLFontFeature(\%font_size_hash, \%font_face_hash);
   				UpdateXMLFeatures($bold_count, $italic_count, $words_count, $lines->[ $t ]->get_bullet(), $space);
			}
		}
		
		# Reset hash
		%font_size_hash = (); 
		%font_face_hash = ();
		# Reset
		$bold_count		= 0;
		$italic_count	= 0;
	}

  	return ($all_text, $l, $t, $r, $bottom, $is_space);
}

sub UpdateXMLFontFeature 
{
	my ($font_size_hash, $font_face_hash) = @_;

  	# Font size feature
  	if (scalar(keys %{ $font_size_hash }) == 0)
	{
    	push @g_font_size, -1;
  	} 
	else 
	{
    	my @sorted_fonts = sort { $font_size_hash->{ $b } <=> $font_size_hash->{ $a } } keys %{ $font_size_hash };
   
    	my $font_size = $sorted_fonts[ 0 ];
    	push @g_font_size, $font_size;
    
    	$g_font_size_hash{ $font_size } = $g_font_size_hash{ $font_size } ? $g_font_size_hash{ $font_size } + 1 : 1;
  	}
  
  	# Font face feature
  	if (scalar(keys %{ $font_face_hash }) == 0)
	{
    	push @g_font_face, "none";
  	} 
	else 
	{
    	my @sorted_fonts = sort { $font_face_hash->{ $b } <=> $font_face_hash->{ $a } } keys %{ $font_face_hash };

    	my $font_face = $sorted_fonts[ 0 ];
    	push @g_font_face, $font_face;
    
    	$g_font_face_hash{ $font_face } = $g_font_face_hash{ $font_face } ? $g_font_face_hash{ $font_face } + 1 : 1;
  	}
}

sub UpdateXMLFeatures 
{
	my ($bold_count, $italic_count, $words_count, $is_bullet, $space) = @_;

	# Bold feature
  	my $bold_feature = undef;
  	if ($bold_count / $words_count >= 0.667)
	{
    	$bold_feature = "yes";
  	} 
	else 
	{
    	$bold_feature = "no";
  	}
  	push @g_bold, $bold_feature;
  
  	# Italic feature
  	my $italic_feature = undef;
  	if ($ln_italic_count / $words_count >= 0.667)
	{
    	$italic_feature = "yes";
  	} 
	else 
	{
    	$italic_feature = "no";
  	}
  	push @g_italic, $italic_feature;
  
  	# Bullet feature
  	if ($is_bullet)
	{
    	push @g_bullet, "yes";
  	} 
	else 
	{
    	push @g_bullet, "no";
  	}
}

# Find the positions of header, body, and citation
sub GetStructureInfo 
{
  	my ($lines, $num_lines) = @_;

  	my ($body_length, $citation_length, $body_end_id) = SectLabel::PreProcess::findCitationText($lines, 0, $num_lines);
  
  	my ($header_length, $body_start_id);

	($header_length, $body_length, $body_start_id) = SectLabel::PreProcess::findHeaderText($lines, 0, $body_length);
  
  	# Sanity check
  	my $totalLength = $header_length + $body_length + $citation_length;
 
 	if ($num_lines != $totalLength)
	{
    	print STDOUT "Die in getStructureInfo(): different num lines $num_lines != $totalLength\n"; # to display in Web
    	die "Die in getStructureInfo(): different num lines $num_lines != $totalLength\n";
  	}
  
  	return ($header_length, $body_length, $citation_length, $body_start_id, $body_end_id);
}

# Count XML tags/values for statistics purpose
sub ProcessTagInfo 
{
	my ($line, $tags) = @_;

  	my $tag;
  	my $attr;
  
  	if ($line =~ /^<(.+?)\b(.*)/)
	{
    	$tag = $1;
    	$attr = $2;
    	if (!$tags->{$tag})
		{
      		$tags->{$tag} = ();
    	}	
    
		if ($attr =~ /^\s*(.+?)\s*\/?>/)
		{
      		$attr = $1;
    	}
    
    	my @tokens = split(/\s+/, $attr);
    	foreach my $token (@tokens)
		{
      		if($token =~ /^(.+)=(.+)$/)
			{
				my $attr_name = $1;
				my $value = $2;
	
				if (!$tags->{$tag}->{$attr_name})
				{
	  				$tags->{$tag}->{$attr_name} = ();
				}
				if (!$tags->{$tag}->{$attr_name}->{$value})
				{
	  				$tags->{$tag}->{$attr_name}->{$value} = 0;
				}
				$tags->{$tag}->{$attr_name}->{$value}++;
      		}
    	}
  	}
}

# Print tag info to file
sub PrintTagInfo 
{
	my ($tags, $tag_file) = @_;

  	open(TAG, ">:utf8", "$tag_file") || die"#Can't open file \"$tag_file\"\n";

	my @sortedTags = sort {$a cmp $b} keys %{$tags};

  	foreach(@sortedTags)
	{
    	my @attrs = sort {$a cmp $b} keys %{$tags->{$_}};
    	print TAG "# Tag = $_\n";
    	
		foreach my $attr (@attrs) 
		{
      		print TAG "$attr:";
      		my @values = sort {$a cmp $b} keys %{$tags->{$_}->{$attr}};
      		
			foreach my $value (@values)
			{
				print TAG " $value-$tags->{$_}->{$attr}->{$value}";
      		}
      
	  		print TAG "\n";
    	}
  	}
  
  	close TAG;
}

sub UntaintPath 
{
	my ($path) = @_;

  	if ( $path =~ /^([-_\/\w\.]*)$/ ) 
	{
    	$path = $1;
  	} 
	else 
	{
    	die "Bad path \"$path\"\n";
  	}

  	return $path;
}

sub Untaint 
{
	my ($s) = @_;
  	if ($s =~ /^([\w \-\@\(\),\.\/]+)$/) 
	{
    	$s = $1;               # $data now untainted
  	} 
	else 
	{
    	die "Bad data in $s";  # log this somewhere
  	}
  	
	return $s;
}

sub Execute 
{
	my ($cmd) = @_;
  	
	if ($is_debug)
	{
    	print STDERR "Executing: $cmd\n";
  	}
  
  	$cmd = Untaint($cmd);
	system($cmd);
}

sub NewTmpFile 
{
	my $tmpFile = `date '+%Y%m%d-%H%M%S-$$'`;
  	chomp($tmpFile);
  	return $tmpFile;
}



