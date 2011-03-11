#!/cygdrive/c/Perl/bin/perl -w
#****************************************************/
#* File: scanner.pl                                 */
#* Scanner implementation                           */
#* for the C- compiler                              */
#* Cesar Carrasco / Steve Hammond                   */
#****************************************************/

# use strict to make sure our code is up to Perl standards:
use strict;

# define bool constants for readability:
use constant TRUE  => 1;
use constant FALSE => 0;

our $linecount = 0;

# This is a hack (we will have to handle multiple files later:
our $filename = $ARGV[0];

our @keywords       = ( "if", "else", "void", "int", "return", "while" );

our %keywordTokens  = ( "if"    => "IF",
                        "else"  => "ELSE",
                        "void"  => "VOID",
                        "int"   => "INT",
                        "return"=> "RETURN",
                        "while" => "WHILE" );

our @symbols        = ( "/*", "*/", "+", "-", "*", "/", "<=", "<", ">=", ">",
                        "==", "!=", "=", ";", ",", "(", ")", "[", "]", "{", "}" );

our %symbolTokens   = ( "/*"=> "COMMENT_START",
                        "*/"=> "COMMENT_STOP",
                        "+" => "PLUS",
                        "-" => "MINUS",
                        "*" => "TIMES",
                        "/" => "DIVIDE",
                        "<="=> "LTEQ",
                        "<" => "LT",
                        ">="=> "GTEQ",
                        ">" => "GT",
                        "=="=> "EQ",
                        "!="=> "NOTEQ",
                        "=" => "ASSIGN",
                        ";" => "SEMICOLON",
                        "," => "COMMA",
                        "(" => "LPAREN",
                        ")" => "RPAREN",
                        "[" => "LBRACKET",
                        "]" => "RBRACKET",
                        "{" => "LBRACE",
                        "}" => "RBRACE" );
my $InComment = 0;

#for now we will only hadle one file (the first argument)

#open the file
if (!open(INPUT_FILE, $filename))
{
	die "Cannot find file $filename \n";
}

#print "--File opened.--\n\n";

open (TOKENFILE, '+>tokens.txt');

#variable to hold each line read in
my $line;

#while we are not at EOF, process each line
while(my $line = <INPUT_FILE>)
{ # open main while loop

    # Keep track of how many lines we've read in so far
    ++$linecount;

    # Store all strings that are separated by spaces in an array:
    my @words;
    my $word;
    my $LengthOfLine = -1;

    #don't evaluate blank lines
    if ($line =~ /\S/)
    {
        #chomp off newlines from the line of code
        chomp($line);

        #strip off any tab characters
        $line =~ s/\t//g;

        #while the line is not empty (we remove the first match from the line with each iteration)
        while ($line ne "")
        {
            #set the default input and pattern-searching space.
            $_ = $line;

            #regular expression for matching tokens in a line
            $line =~ /[\s]+|[a-zA-Z]+|[0-9]+|(\/\*)|(\*\/)|>=|<=|!=|\+|\-|\*|\/|<|>|(=){1,2}|;|,|\(|\)|\[|\]|\{|\}/;

            # store the string matched by the last successful pattern match.
            $word = $&;

            #store the string preceding whatever was matched by the last successful pattern match.
            $line = $';
            
            #Check if we found a comment, if so go through the file trashing the info until a closing comment is found
            if ($word eq "/*")
            {
                #Read in lines until we see a closing comment
                my $TempCount = 0;
                $line =~ /(\*\/)/;
                until ($& eq "*/")
                {
                    $line = <INPUT_FILE>;
                    if ( !defined($line) )
                    {
                        print "Error - Must close comments";
                        exit;
                    }
                    
                    ++$linecount;
                    $line =~ m/(\*\/)/;
                    $line = $';
                    
                    ++$TempCount;
                }
                
                #Store the line after the comment
                if ($TempCount == 0)
                {
                    $line = $';
                }
                
                #Reset the length of the line
                $LengthOfLine = -1;
                
                next;
            }
            
    	    #Check for inconsistancies, if the length of the line hasn't changed, there is an error, stop and report it
    	    if ($LengthOfLine == length($line))
    	    {
                print "Error in line $linecount, invalid token";
                exit;
	        }
	        $LengthOfLine = length($line);

            #unless the word is full of space characters, push the matched word into an array
            unless ( $word =~ /\s+/ )
            {
                push (@words, $word);
            }
        }
    }

    # For each string, determine the appropriate token type:
    foreach $word (@words)
    { # Open word process foreach

        # A flag to notify us when we've found a token
        my $found = FALSE;

        # print a keyword if it was found
        foreach my $keyword (@keywords)
        {
            # try to match with every keyword
            if($word eq $keyword)
            {
                #report that a keyword was found, mark it and break out
                if (!$InComment)
                {
                    print TOKENFILE "$linecount\: keyword: $keywordTokens{$keyword}\n";
                }
                $found = TRUE;
                last;
            }
        }

        # if a keyword was found, continue to the next word in the line
        if ($found)
        {
            next;
        }

        # print that we found a symbol (;, +, etc...)
        foreach my $symbol (@symbols)
        {
            if($word eq $symbol)
            {
                # report if a symbol was found, mark that something was found and break out
                if (!$InComment || $symbol eq "*/")
                {
                    print TOKENFILE "$linecount\: symbol: $symbolTokens{$symbol}\n";
                }
                $found = TRUE;

                # SPECIAL CASE: make a note if we found an opening comment symbol
                if ($symbol eq "/*")
                {
                    $InComment = $InComment + 1;
                }
                if ($symbol eq "*/")
                {
                    $InComment = $InComment - 1;
                }
                last;
            }
        }

        # if something was found continue to the next word in the line
        if ($found)
        {
            next;
        }

        # print that we found an ID
        if ($word =~ m/([a-zA-Z]+)/)
        {
            if (!$InComment)
            {
                print TOKENFILE "$linecount\: ID: $1\n";
            }
            next;
        }

        # print that we found a number
        if ($word =~ m/([0-9]+)/)
        {
            if (!$InComment)
            {
                print TOKENFILE "$linecount\: NUM: $1\n";
            }
            next;
        }

    } #close Word process foreach
} #close main while loop

print TOKENFILE "EOF\n";

#print "\n--File closed.--\n";

close(TOKENFILE);



# We should return the tokenfile later on.  For now, the parser will look for it.


