package Omni::Traversal;

# Configuration
use strict;

# Local libraries
use Omni::Config;

# Omnilib configuration: object name
my $obj_list = $Omni::Config::obj_list;

###
# 16 Feb 2010: Do Hoang Nhat Huy
# Omni lib is used to handle the Omnipage XML in a generic 
# and 'elegent' way. The hierachical structure of the classes
# reflects the XML tree as follow
# Omnidoc
# |
# Omnipage (obviously, one document can have many pages)
# |__________________________________
# ||								||
# Omnicol (columns in a page)		Omnidd (image?)
# |									|
# |									Omnidd (nested)
# |_________________________________|
# |									|
# Omnipara (a paragraph)			Omnitable (a table)
# |									|
# |									Omnicell (a cell)
# |									|
# |									Omnipara (a paragraph)
# |_________________________________|
# 				|
# 				Omniline (a line)
# 				|
# 				Omnirun (a run, text of the same format)
# 				|
# 				Omniword (an individual word)
#
# This module provide a generic way to travel the whole tree
# to access each line of the document. Each line will have a
# group of identification (index) as follow
#	page id; 
# 	column id or dd id; 
# 	column id or dd id;*
# 	table id;
# 	cell id;
# 	para id;
# 	line id;
# *: both dd and column can be nested inside each other
###

###
# Huydhn: travel the Omnidoc at line level
###
sub OmniAirline
{
	# Omnidoc object
	# Starting position 
	# Ending position
	# Both positons are hash with following members
	# 'L1'		: page
	# 'L2'		: collumn or dd
	# 'L21'		: -1 if unavailable, unused for now
	# 'L3'		: table or paragraph 
	# 'L4'		: line in paragraph or table
	my ($doc, $start, $end) = @_;

	# All the line 
	my @line_pos	 = ();
	my @line_content = ();

	# Current position	
	my %current		 = ();

	# All pages in the document
	my $pages = $doc->get_objs_ref();

	# From page, To page
	my $start_page	= (defined $start)	? $start->{ 'L1' }	: 0;
	my $end_page	= (defined $end)	? $end->{ 'L1' }	: (scalar(@{ $pages }) - 1);

	# Tree traveling is 'not' fun. Seriously.
	# This is like a dungeon seige.
	for (my $x = $start_page; $x <= $end_page; $x++)	
	{
		# Current position
		%current->{ 'L1' } = $x;

		# Column or dd
		my $level_2	 =	$pages->[ $x ]->get_objs_ref();
		my $start_l2 =	((defined $start) && ($x == $start->{ 'L1' }))	? 
						$start->{ 'L2' }	: 0;
		my $end_l2	 =	((defined $end) && ($x == $end->{ 'L1' }))	? 
						$end->{ 'L2' }	: (scalar(@{ $level_2 }) - 1);

		for (my $y = $start_l2; $y <= $end_l2; $y++)
		{
			# Current position
			%current->{ 'L2' } = $y;

			# Table or paragraph
			my $level_3	 = 	$level_2->[ $y ]->get_objs_ref();
			my $start_l3 =	((defined $start) && ($x == $start->{ 'L1' }) && ($y == $start->{ 'L2' }))	? 
							$start->{ 'L3' }	: 0;
			my $end_l3	 =	((defined $end) &&($x == $end->{ 'L1' }) && ($y == $end->{ 'L2' }))		? 
							$end->{ 'L3' }	: (scalar(@{ $level_3 }) - 1);

			for (my $z = $start_l3; $z <= $end_l3; $z++)
			{
				# Current position
				%current->{ 'L3' } = $z;

				# Is a paragraph
				if ($level_3->[ $z ]->get_name() eq $obj_list->{ 'OMNIPARA' })
				{
					# Line or cell
					my $level_4	 =	$level_3->[ $z ]->get_objs_ref();
					my $start_l4 =	((defined $start) && ($x == $start->{ 'L1' }) && ($y == $start->{ 'L2' }) && ($z == $start->{ 'L3' }))	? 
									$start->{ 'L4' }	: 0;
					my $end_l4	 =	((defined $end) && ($x == $end->{ 'L1' }) && ($y == $end->{ 'L2' }) && ($z == $end->{ 'L3' }))			? 
									$end->{ 'L4' }		: (scalar(@{ $level_4 }) - 1);

					# Lines
					for (my $t = $start_l4; $t <= $end_l4; $t++)
					{
						# Current position
						%current->{ 'L4' } = $t;

						# Save the current position and the content of the current line
						push @line_pos, %current;
						push @line_content, $level_4->[ $t ]->get_content();
					}					
				}
				# Is a table
				elsif ($level_3->[ $z ]->get_name() eq $obj_list->{ 'OMNITABLE' })
				{
					# TODO: this actually a trick to get it working for now.
					# We care not about the cell inside the table but the content
					# of the table only. So the table is consider a paragraph in
					# which lines are its row
					my @level_4 = split(/\n/, $level_3->[ $z ]->get_content());
				
					for (my $t = 0; $t <= scalar(@level_4); $t++)
					{
						# Current position
						%current->{ 'L4' } = $t;

						# Save the current position and the content of the current line
						push @line_pos, %current;
						push @line_content, $level_4[ $t ];
					}
				}
			}
		}
	}

	return (\@line_pos, \@line_content);
}

1;
