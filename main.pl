#!/cygdrive/c/Perl/bin/perl -w
#****************************************************/
#* File: main.pl                                    */
#* Program Entry                                    */
#* for the C- compiler                              */
#* Cesar Carrasco / Steve Hammond                   */
#****************************************************/

# use strict to make sure our code is up to Perl standards:
use strict;

# handle to file:
our $filename;

#for now we will only hadle one file (the first argument)
if(@ARGV == 0)
{
    # if there are no arguments provided, kill the program:
    die "Input file required.\n";
}
else #assume the first argument is the filename
{    
    $filename = $ARGV[0];

    #check for a valid file extension
    if ($filename =~ /^[a-zA-Z0-9\.\/\\_\-]+(.cmi)$/)
    {
        # Call other compiler modules (other perl files):
        system("scanner.pl $filename");
        
        if($? == 0)
        {
            print "Scanner Finished! \n";
            system("parser.pl $filename tokens.txt -s > test.sem");
            
            if($? == 0)
            {
                print "Parser Finished! \n";
		        system("analyze.pl test.sem");
		        
		        if($? == 0)
		        {
                    print "Semantic Analyzer Finished! \n";
                }
            }
        }
    }
    else
    {
        die "Invalid file type: '.cmi' extension required!\n";
    }
}

