package Omni::Omnidd;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omnicol;
use Omni::Omniimg;
use Omni::Omnipara;
use Omni::Omnitable;

# Extern libraries
use XML::Twig;
use XML::Parser;

# Global variables
my $tag_list = $Omni::Config::tag_list;
my $att_list = $Omni::Config::att_list;
my $obj_list = $Omni::Config::obj_list;

# Temporary variables
my $tmp_content 	= undef;
my $tmp_bottom		= undef;
my $tmp_top			= undef;
my $tmp_left		= undef;
my $tmp_right		= undef;
my $tmp_bottom_dist	= undef;
my $tmp_top_dist	= undef;
my $tmp_left_dist	= undef;
my $tmp_right_dist	= undef;
my @tmp_objs		= ();

###
# A dd object in Omnipage xml: a dd, don't know what it is, but its structure 
# is quite similar to a column
#
# Do Hoang Nhat Huy, 11 Jan 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# dd: a dd can have many tables, or pictures, may be paras, and columns
	my @objs	= ();

	# Class members
	my $self = {	'_self'			=> $obj_list->{ 'OMNIDD' },
					'_raw'			=> undef,
					'_content'		=> undef,
					'_bottom'		=> undef,
					'_top'			=> undef,
					'_left'			=> undef,
					'_right'		=> undef,
					'_bottom_dist'	=> undef,
					'_top_dist'		=> undef,
					'_left_dist'	=> undef,
					'_right_dist'	=> undef,
					'_objs'			=> \@objs	};

	bless $self, $class;
	return $self;
}

# 
sub set_raw
{
	my ($self, $raw) = @_;

	# Save the raw xml <column> ... </column>
	$self->{ '_raw' }	= $raw;

	# Parse the raw string
	my $twig_roots		= { $tag_list->{ 'DD' }	=> 1 };
	my $twig_handlers 	= { $tag_list->{ 'DD' }	=> \&parse};

	# XML::Twig 
	my $twig = new XML::Twig(	twig_roots 		=> $twig_roots,
						 	 	twig_handlers	=> $twig_handlers,
						 	 	pretty_print 	=> 'indented'	);

	# Start the XML parsing
	$twig->parse($raw);
	$twig->purge;

	# Copy information from temporary variables to class members
	$self->{ '_bottom' }		= $tmp_bottom;
	$self->{ '_top' }			= $tmp_top;
	$self->{ '_left' }			= $tmp_left;
	$self->{ '_right' } 		= $tmp_right;
	$self->{ '_bottom_dist' }	= $tmp_bottom_dist;
	$self->{ '_top_dist' }		= $tmp_top_dist;
	$self->{ '_left_dist' }		= $tmp_left_dist;
	$self->{ '_right_dist' }	= $tmp_right_dist;

	# Copy all objects 
	@{$self->{ '_objs' } }	= @tmp_objs;
	
	# Copy content
	$self->{ '_content' }	= $tmp_content;
}

sub get_raw
{
	my ($self) = @_;
	return $self->{ '_raw' };
}

sub parse
{
	my ($twig, $node) = @_;

	# At first, content is blank
	$tmp_content	= "";
	# because there's no object
	@tmp_objs		= ();

	# Get <column> node attributes
	$tmp_bottom			= GetNodeAttr($node, $att_list->{ 'BOTTOM' });
	$tmp_top			= GetNodeAttr($node, $att_list->{ 'TOP' });
	$tmp_left			= GetNodeAttr($node, $att_list->{ 'LEFT' });
	$tmp_right			= GetNodeAttr($node, $att_list->{ 'RIGHT' });
	$tmp_bottom_dist	= GetNodeAttr($node, $att_list->{ 'BOTTOMDIST' });
	$tmp_top_dist		= GetNodeAttr($node, $att_list->{ 'TOPDIST' });
	$tmp_left_dist		= GetNodeAttr($node, $att_list->{ 'LEFTDIST' });
	$tmp_right_dist		= GetNodeAttr($node, $att_list->{ 'RIGHTDIST' });

	# Check if there's any paragraph, col, table, or picture 
	# The large number of possible children is due to the
	# ambiguous structure of the Omnipage XML
	my $dd_tag		= $tag_list->{ 'DD' };
	my $img_tag		= $tag_list->{ 'PICTURE' };
	my $para_tag	= $tag_list->{ 'PARA' };
	my $table_tag	= $tag_list->{ 'TABLE' };
	my $column_tag	= $tag_list->{ 'COLUMN' };

	my $child = undef;
	# Get the first child in the body text
	$child = $child->first_child();

	while (defined $child)
	{
		my $xpath = $child->path();

		# if this child is a <para> tag
		if ($xpath =~ m/\/$para_tag$/)
		{
			my $para = new Omni::Omnipara();

			# Set raw content
			$para->set_raw($child->sprint());

			# Update paragraph list
			push @tmp_objs, $para;

			# Update content
			$tmp_content = $tmp_content . $para->get_content() . "\n";
		}
		# if this child is a <dd> tag
		elsif ($xpath =~ m/\/$dd_tag$/)
		{
			my $dd = new Omni::Omnidd();

			# Set raw content
			$dd->set_raw($child->sprint());

			# Update paragraph list
			push @tmp_objs, $dd;

			# Update content
			$tmp_content = $tmp_content . $dd->get_content() . "\n";
		}
		# if this child is a <table> tag
		elsif ($xpath =~ m/\/$table_tag$/)
		{
			my $table = new Omni::Omnitable();

			# Set raw content
			$table->set_raw($child->sprint());

			# Update paragraph list
			push @tmp_objs, $table;

			# Update content
			$tmp_content = $tmp_content . $table->get_content() . "\n";
		}
		# if this child is a <picture> tag
		elsif ($xpath =~ m/\/$img_tag$/)
		{
			my $img = new Omni::Omniimg();

			# Set raw content
			$img->set_raw($child->sprint());

			# Update paragraph list
			push @tmp_objs, $img;

			# Update content
			$tmp_content = $tmp_content . $img->get_content() . "\n";
		}
		# if this child is a <column> tag
		elsif ($xpath =~ m/\/$column_tag$/)
		{
			my $col = new Omni::Omnicol();

			# Set raw content
			$col->set_raw($child->sprint());

			# Update paragraph list
			push @tmp_objs, $col;

			# Update content
			$tmp_content = $tmp_content . $col->get_content() . "\n";
		}

		# Little brother
		if ($child->is_last_child) 
		{ 
			last; 
		}
		else
		{
			$child = $child->next_sibling();
		}
	}
}

sub get_name
{
	my ($self) = @_;
	return $self->{ '_self' };
}

sub get_objs_ref
{
	my ($self) = @_;
	return $self->{ '_objs' };
}

sub get_content
{
	my ($self) = @_;
	return $self->{ '_content' };
}

sub get_bottom_pos
{
	my ($self) = @_;
	return $self->{ '_bottom' };
}

sub get_top_pos
{
	my ($self) = @_;
	return $self->{ '_top' };
}

sub get_left_pos
{
	my ($self) = @_;
	return $self->{ '_left' };
}

sub get_right_pos
{
	my ($self) = @_;
	return $self->{ '_right' };
}

sub get_bottom_distance
{
	my ($self) = @_;
	return $self->{ '_bottom_dist' };
}

sub get_top_distance
{
	my ($self) = @_;
	return $self->{ '_top_dist' };
}

sub get_left_distance
{
	my ($self) = @_;
	return $self->{ '_left_dist' };
}

sub get_right_distance
{
	my ($self) = @_;
	return $self->{ '_right_dist' };
}

# Support functions
sub GetNodeAttr 
{
	my ($node, $attr) = @_;
	return ($node->att($attr) ? $node->att($attr) : "");
}

sub SetNodeAttr 
{
	my ($node, $attr, $value) = @_;
	$node->set_att($attr, $value);
}

sub GetNodeText
{
	my ($node) = @_;
	return $node->text;
}

sub SetNodeText
{
	my ($node, $value) = @_;
	$node->set_text($value);
}

1;
