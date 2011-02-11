package Omni::Omnitable;

# Configuration
use strict;

# Local libraries
use Omni::Config;
use Omni::Omnicell;

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
my $tmp_alignment	= undef;

# My observation is that <table> contains <gridTable> and <cell>
# <gridTable> contain the base grid's coordinates
# <cell> contain the cell's position based on <gridTable> coordinates
# and various types of objects: <picture>, <para>, may be even <dd> but
# I'm not quite sure about this
my @tmp_objs		= ();

###
# A table object in Omnipage xml: a table contains cells with various objects
#
# Do Hoang Nhat Huy, 11 Feb 2011
###
# Initialization
sub new
{
	my ($class) = @_;

	# Objs: a paragraph can have many cells
	my @objs	= ();

	# Class members
	my $self = {	'_self'			=> $obj_list->{ 'OMNITABLE' },
					'_raw'			=> undef,
					'_content'		=> undef,
					'_bottom'		=> undef,
					'_top'			=> undef,
					'_left'			=> undef,
					'_right'		=> undef,
					'_alignment'	=> undef,
					'_objs'			=> \@objs	};

	bless $self, $class;
	return $self;
}

1;
