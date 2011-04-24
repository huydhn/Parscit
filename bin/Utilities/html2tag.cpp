/*!	\brief Process the html output from my tagtool 
 * 
 * 	Just a utilitty program. There's nothing more to say about it
 * 	right now.
 */

#include <iomanip>
#include <fstream>
#include <iostream>

#include <argtable2.h>
#include <boost/regex.hpp>
#include <boost/algorithm/string.hpp>

using namespace std;
using namespace boost;

// Argument
struct arg_end *des;
struct arg_str *infile;
struct arg_str *outfile;
struct arg_lit *help;

// Function declaration
bool html2tag(std::ifstream & input, std::ostream & output);

int main(int argc, char** argv)
{
	// Parse commandline syntax
	void *argtable[] = 
	{
		infile	= arg_str1("i", "in", "INPUT", "html output from tagtool"),
		outfile	= arg_str0("o", "out", "OUTPUT", "tagged text"),
		help	= arg_lit0("h", "help", "display this help and exit"),
		des		= arg_end(32)
	};

	const char *progname = "html2tag";
	
	if (arg_nullcheck(argtable) != 0)
	{
        // NULL entries were detected, some allocations must have failed
        std::cerr << progname << ": insufficient memory" << std::endl;
		arg_freetable(argtable, sizeof(argtable) / sizeof(argtable[0]));
		return (EXIT_FAILURE);
    }

	int nerrors = arg_parse(argc, argv, argtable);

	// Special case: '--help' takes precedence over error reporting
    if (help->count > 0)
	{
		std::cout << "Usage: " << progname;
		arg_print_syntax(stdout, argtable, "\n");
        arg_print_glossary(stdout, argtable,"  %-25s %s\n");
		arg_freetable(argtable, sizeof(argtable) / sizeof(argtable[0]));
		return (EXIT_SUCCESS);
	}

	// If the parser returned any errors then display them and exit
	if (nerrors > 0)
	{
        // Display the error details contained in the arg_end struct.
        arg_print_errors(stdout, des, progname);
        std::cerr << "Try '" << progname << " --help' for more information." << std::endl;
		arg_freetable(argtable, sizeof(argtable) / sizeof(argtable[0]));
		return (EXIT_FAILURE);
	}

	std::ifstream input(infile->sval[0]);
	// Check the input
	if (! input.is_open()) { std::cerr << "Cannot open " << infile->sval[0] << "." << std::endl; return (EXIT_FAILURE); }

	// The output can be another file or the standard output
	if (outfile->count > 0)
	{
		std::ofstream output(outfile->sval[0]);
		// Check the output
		if (! output.is_open()) { std::cerr << "Cannot open " << outfile->sval[0] << "." << std::endl; return (EXIT_FAILURE); }
		// Preprocess step
		html2tag(input, output);
		// Close output
		output.close();
	}
	else
	{
		// The output is the standard output
		html2tag(input, std::cout);	
	}

	// Close input
	input.close();
	return (EXIT_SUCCESS);
}

/*!	\brief Convert html from tagtool to tagged text
 *
 * 	\param input input stream
 * 	\param output output stream
 * 	\return status
 */
bool html2tag(std::ifstream & input, std::ostream & output)
{
	std::string line;
	std::string html_text;
	std::string tagged_text;

	// Read the whole file
	while (getline(input, line)) { html_text += line + "\n"; }

	// Find all the rows
	boost::regex const html_row_regex("<tr>(.+?)</tr>");
	boost::smatch what;
	// in the html
	std::string::const_iterator s = html_text.begin();
	std::string::const_iterator e = html_text.end();
	// now
	while (boost::regex_search(s, e, what, html_row_regex))
	{
		// Tag or content
		int field = 0;

		// Find all cell
		boost::regex const html_cell_regex("<td>(.+?)</td>");
		boost::smatch what_again;
		// in the row
		std::string::const_iterator rs = what[1].first;
		std::string::const_iterator re = what[1].second;
		// now
		std::string tmpa, tmpb;
		while (boost::regex_search(rs, re, what_again, html_cell_regex))
		{
			// Cell content
			std::string cell(what_again[1].first, what_again[1].second);
			// Remove all tags left
			boost::regex const html_tag_regex("<.+?>");
			cell = boost::regex_replace(cell, html_tag_regex, "");
			// Then, save the cell content
			if (field == 0)
			{
				trim(cell);
				tmpa	= cell;
				field	= (field + 1) % 2;
			}
			else
			{
				trim(cell);
				tmpb	= cell;
				field	= (field + 1) % 2;
			}

			// Next cell
			rs = what_again[0].second;
		}

		// Save row
		if (tmpb.length() != 0)
		{
			tagged_text += tmpb + "\t" + tmpa + "\n";
		}
		else
		{
			tagged_text += "\n";
		}

		// Next row
		s = what[0].second;
	}

	// Save everything
	output << tagged_text;
	return true;
}











