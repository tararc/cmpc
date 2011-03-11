#!/cygdrive/c/Perl/bin/perl -w
#****************************************************/
#* File: analyze.pl                                 */
#* Program Entry                                    */
#* for the C- compiler                              */
#* Cesar Carrasco / Steve Hammond                   */
#****************************************************/

# use strict to make sure our code is up to Perl standards:
use strict;

# Abstract quick reference definitions for types of parent nodes
our $DECLARATION_LIST_TYPE      = 'D';
our $DECLARATION_TYPE           = 'd';
our $VAR_DECLARATION_TYPE       = 'V';
our $TYPE_SPECIFIER_TYPE        = 't';
our $FUN_DECLARATION_TYPE       = 'F';
our $PARAMS_TYPE                = 'R';
our $PARAM_LIST_TYPE            = 'p';
our $COMPOUND_STMT_TYPE         = 'C';
our $LOCAL_DECLARATION_TYPE     = 'L';
our $STATEMENT_LIST_TYPE        = 'S';
our $STATEMENT_TYPE             = 's';
our $EXPRESSION_STMT_TYPE       = 'E';
our $SELECTION_STMT_TYPE        = 'I';
our $ITERATION_STMT_TYPE        = 'i';
our $RETURN_STMT_TYPE           = 'U';
our $EXPRESSION_TYPE            = 'e';
our $VAR_TYPE                   = 'v';
our $SIMPLE_EXPRESSION          = 'X';
our $RELOP_TYPE                 = 'o';
our $ADDITIVE_EXPRESSION        = 'A';
our $TERM_TYPE                  = 'T';
our $MULOP_TYPE                 = 'm';
our $FACTOR_TYPE                = 'F';
our $CALL_TYPE                  = 'c';
our $ARGS_TYPE                  = 'G';
our $ARG_LIST_TYPE              = 'g';

# Why 5 and 7? no reason, they are arbitrary, as long as they are not the same
our $INTEGER                    = 5;
our $ARRAY                      = 7;

# macros for matching tokens with regex's:
our $COMMENT_START  = "([0-9]+:)( symbol:)( COMMENT_START)";
our $COMMENT_STOP   = "([0-9]+:)( symbol:)( COMMENT_STOP)";
our $PLUS           = "([0-9]+:)( symbol:)( PLUS)";
our $MINUS          = "([0-9]+:)( symbol:)( MINUS)";
our $TIMES          = "([0-9]+:)( symbol:)( TIMES)";
our $DIVIDE         = "([0-9]+:)( symbol:)( DIVIDE)";
our $LTEQ           = "([0-9]+:)( symbol:)( LTEQ)";
our $LT             = "([0-9]+:)( symbol:)( LT)";
our $GTEQ           = "([0-9]+:)( symbol:)( GTEQ)";
our $GT             = "([0-9]+:)( symbol:)( GT)";
our $EQ             = "([0-9]+:)( symbol:)( EQ)";
our $NOTEQ          = "([0-9]+:)( symbol:)( NOTEQ)";
our $ASSIGN         = "([0-9]+:)( symbol:)( ASSIGN)";
our $SEMICOLON      = "([0-9]+:)( symbol:)( SEMICOLON)";
our $COMMA          = "([0-9]+:)( symbol:)( COMMA)";
our $LPAREN         = "([0-9]+:)( symbol:)( LPAREN)";
our $RPAREN         = "([0-9]+:)( symbol:)( RPAREN)";
our $LBRACKET       = "([0-9]+:)( symbol:)( LBRACKET)";
our $RBRACKET       = "([0-9]+:)( symbol:)( RBRACKET)";
our $LBRACE         = "([0-9]+:)( symbol:)( LBRACE)";
our $RBRACE         = "([0-9]+:)( symbol:)( RBRACE)";

our $IF             = "([0-9]+:)( keyword:)( IF)";
our $ELSE           = "([0-9]+:)( keyword:)( ELSE)";
our $VOID           = "([0-9]+:)( keyword:)( VOID)";
our $INT            = "([0-9]+:)( keyword:)( INT)";
our $RETURN         = "([0-9]+:)( keyword:)( RETURN)";
our $WHILE          = "([0-9]+:)( keyword:)( WHILE)";

our $ID             = "([0-9]+:)( ID:)( [a-zA-Z]+)";
our $NUM            = "([0-9]+:)( NUM:)( [0-9]+)";

# Start our hash table here
our %varTable;
our %funTable;

package Variable;
use Class::Struct;
struct (
        type => '$',
        depth => '$'
        );

# Input token file from scanner:
our $treeFile = $ARGV[0];

#open the token file:
if (!open(TOKEN_FILE, $treeFile))
{
    # if we can't open the file, kill the program:
	die "Cannot find file $treeFile \n";
}

# Array and index counter to store all tokens listed in the token file:
our @tree;
our $treeIndex = 0;

# Read tokens in token file and store each as an element in an array:
while(my $currentLine = <TOKEN_FILE>)
{
    # Remove newlines:
    chomp($currentLine);

    # Add current token to array:
    push(@tree, $currentLine);
}

# Close token file:
close(TOKEN_FILE);
our $maxIndex = @tree;

# Will find the depths of the leaf currently being looked at
my $currentDepth = 0;


# Gets the parent of the leaf being examined
sub GetParent
{
    my $retVal;
    $tree[$treeIndex] =~ m/[\s]/;
    $retVal = $`;
    return chop($retVal);
}

# Set the depths we are currently at in the code
sub AdjustDepth
{
    # This counts the number of nested compound statements we are in
    if($treeIndex < $maxIndex)
    {
        $tree[$treeIndex] =~ m/[\s]/;
        $currentDepth = ($` =~ tr/C//);
    }
}

sub IsInVarTable
{
    my ($Name) = @_;
    my $DepthTracker = chop($Name);
    
    # See if the name is in the var table at its current level or any level lower
    while ($DepthTracker >= 0)
    {
        if (exists($varTable{$Name . sprintf("%d",$DepthTracker)}))
        {
            return 1;
        }
        
        --$DepthTracker;
    }
    return 0;
}

sub IsInFunTable
{
    my ($Name) = @_;
    chop($Name);
    if (exists($funTable{$Name . sprintf("%d",0)}))
    {
        return 1;
    }
    return 0;
}

sub GetParams
{
    # Some local variables to track the progress through the param list
    my $treeIndexShadow = $treeIndex;
    my @retVal = ();
    
    # A magic number, the param list will start 2 lines down from the function name in the .sem file
    $treeIndex += 2;
    
    # A special case, if there is only one argument, then it will start one more down
    # This is found by looking 2 down
    if ($tree[$treeIndex] =~ m/ param-list/)
    {
        ++$treeIndex;
    }
    
    while(GetParent() eq $PARAM_LIST_TYPE)
    {
        if ($tree[$treeIndex] =~ m/$INT/)
        {
            if ($tree[$treeIndex + 2] =~ m/$LBRACKET/)
            {
                push(@retVal,$ARRAY);
            }
            else
            {
                push(@retVal,$INTEGER);
            }
        }
        ++$treeIndex;
    }
    
    $treeIndex = $treeIndexShadow;
    
    return @retVal;
}

#Syntax Error Message:
sub SyntaxError
{
    my ($line, $token, $message) = @_;
    #chop($token);
	my $indexShadow = $treeIndex;
    for($token)
    {
        s/^\s+//;
        s/\s+$//;
    }

    die "Syntax error on line $line near \'$token\': $message.\n";
};
sub CountArgs
{
    my $argsTracker = 0;
	my $charDepth;
	my $charDepthShadow;
	my $indexShadow = $treeIndex;
	my $callDepth;
	my ($nameOfID, $lineNo) = @_;
	
	# Count the number of embedded calls done in the line, this will hepl track calls taking calls as arguments
	# and prevent miscounting arguments in the case of two calls in a row
	# Count the number of 'c' in this line in the .sem file, 'c' denotes a function call
    $tree[$treeIndex] =~ m/ /;
    $callDepth = ($` =~ tr/c//);
    $tree[$treeIndex] =~ m/ /;
    $charDepthShadow = $charDepth = length($`);
	
	# Go through the lines in the .sem file to count the number of args being passed
	# Break conditions for this loop:
	#   Reached the end of the .sem file
	#   Reached the last line of the current depth level
	#   Reached a line with a lower call depth
	#   Call depth is not zero (this will happen on calls with no args)

    $tree[$treeIndex] =~ m/ /;
	while (($charDepth >= $charDepthShadow) && ($treeIndex < $maxIndex) && ($callDepth <= ($` =~ tr/c//)) && ($callDepth != 0) )
	{ # open while
	
            $tree[$treeIndex] =~ m/ /;
            $charDepth = length($`);
			# Check for things in the arg list that are of the same depths as the first argument, this is another argument
			if (($charDepth == $charDepthShadow) && ($tree[$treeIndex] =~ m/ expression/))
			{ # open if
                    # anytime we see a line that's the correct length it means there's one more argument passed
					++$argsTracker;
			} # close if
			
			# Check for IDs, make sure they are initialized
			if ($tree[$treeIndex] =~ m/$ID/)
			{
                my $IDName = $3;
                my $LineNo = $1;
                unless (IsInFunTable($IDName . "0") || IsInVarTable($IDName . sprintf("%d",$currentDepth)))
                {
                    SyntaxError($LineNo,$IDName,"Use of undeclared variable");
                }
			}
			
			# Check for a call within a call, if there is a call within a call, make a recursive call check
            $tree[$treeIndex] =~ m/ /;
			if ($callDepth < ($` =~ tr/c//))
			{ # open if
                # Reset the counter, and make sure the call within this call is done correctly
                if ($tree[$treeIndex + 1] =~ m/args/)
				{ # open if2
					if (exists($funTable{$nameOfID . sprintf("%d",0)}))
					{ # open if3
						SyntaxError($lineNo, $nameOfID, "Invalid arguments in call");
					} # close if3
				} # close if2

				# Check for a call with the incorrect number of arguments
				if ($tree[$treeIndex + 2] =~ m/ expression/)
				{ #open if2
					#Adjust only two if two lines down is the first expression (this happens for calls with 1 argumentt)
					$treeIndex += 2;
				} # close if2
				else
				{ # open if2
					#Adjust down by three for calls with more than 1 argument
					$treeIndex += 3;
				} # close if2

				AdjustDepth();
				CountArgs($nameOfID, $lineNo);
			} # close if
			
			# Do this calculation iteratively, counting the expression until there is a reason to break out
			++$treeIndex;
			AdjustDepth();
			
			# Setup for the next regular expression check
			if ($treeIndex < $maxIndex)
			{
			    $tree[$treeIndex] =~ m/ /;
            }
	} # close while
	
	# if the number of args passed does not match the number of params expected, there is an error
	# This checks if a param exists at the number of args passed, but one more does not exist
    chop($nameOfID);

    # Not that the number of arguments have been counted, throw an error if there is an invalid number of arguments passed
    if(exists($funTable{$nameOfID . '0'}))
    {
        if($funTable{$nameOfID . '0'} != $argsTracker)
        {
            SyntaxError($lineNo, $nameOfID, "Invalid arguments in call");
        }
    }
}


# Loop through this while the index is in the bounds of the array
while ($treeIndex <= $#tree)
{
    # Increase or decrease the current depth depending on whether we see a curly bracket, or do nothing
    AdjustDepth();

    # First, go through the var table, seeing if there are any variables out of scope
    my $thisDepth = $currentDepth;
    unless ( $tree[$treeIndex] =~ m/compound-stmt/ )
    {
        while ( (my $name, my $var) = each(%varTable))
        {
            if ($var->depth > $thisDepth && GetParent() ne $PARAM_LIST_TYPE)
            {
                delete($varTable{$name});
            }
        }
    }
    
    # Check to see if we are looking at an ID, only operate on lines that are IDs
    if ($tree[$treeIndex] =~ m/$ID/)
    {
        my $nameOfID = $3 . sprintf("%d",$thisDepth);
        my $lineNo = $1;
        my $leafParent = GetParent();
        my $tempVar;
        
        # See if the ID found is a var declaration
        if ($leafParent eq $VAR_DECLARATION_TYPE || $leafParent eq $PARAM_LIST_TYPE)
        {
            # If the ID already exists in the hash table, see if it is a redefinition
            if (exists($varTable{$nameOfID}))
            {
                SyntaxError($lineNo, $nameOfID, "Redefinition of variables");
            }
            
            # If it does not exist, add it to the var table
            else
            {
                if ($leafParent eq $VAR_DECLARATION_TYPE)
                {
                    $tempVar = new Variable;
                    $tempVar->depth($thisDepth);
                    
                    if ($tree[$treeIndex+1] =~ m/$LBRACKET/)
                    {
                        $tempVar->type($ARRAY);
                    }
                    else
                    {
                        $tempVar->type($INTEGER);
                    }
                    
                    $varTable{$nameOfID} = $tempVar;
                }
                # If we are declaring variables in a declaration list, they act as though they were declared in the function below
                elsif ($leafParent eq $PARAM_LIST_TYPE)
                {
                
                    $tempVar = new Variable;
                    $tempVar->depth($thisDepth + 1);

                    if ($tree[$treeIndex] =~ m/$LBRACKET/)
                    {
                        $tempVar->type($ARRAY);
                    }
                    else
                    {
                        $tempVar->type($INTEGER);
                    }
                    
                    chop($nameOfID);
                    $nameOfID .= sprintf("%s",$thisDepth+1);
                    $varTable{$nameOfID} = $tempVar;
                }
            }
        }
        
        # do the same thing again, but see if it's a fun declaration
        elsif ($leafParent eq $FUN_DECLARATION_TYPE)
        {
            # If the ID already exists in the hash table, there is an error, report it
            if (exists($funTable{$nameOfID}))
            {
                SyntaxError($lineNo, $nameOfID, "Invalid function declaration");
            }

            # If it does not exist, add it to the var table
            else
            {
                $funTable{$nameOfID} = GetParams();
            }
        }
        
        # If it wasn't a declaration, see if it's just regular variable usage
        elsif ($leafParent eq $VAR_TYPE)
        {
            # If this variable does not exist in our table, throw an error
            unless (IsInVarTable($nameOfID))
            {
                SyntaxError($lineNo, $nameOfID, "Use of undefined variable");
            }
            
            # do nothing if it does exist
            #else
            #{
            #}
        }
        
        elsif ($leafParent eq $CALL_TYPE)
        {
            # If this function call has not been defined yet, there is an error
            unless (IsInFunTable($nameOfID))
            {
                SyntaxError($lineNo, $nameOfID, "Call to undefined function");
            }
            
            # If this is a valid function name, make sure the correct number of parameters are being passed
            else
            {
					# Check for a call with args to a function without params
					if ($tree[$treeIndex + 1] =~ m/args/)
					{
							if (exists($funTable{$nameOfID . sprintf("%d",0)}))
							{
                                SyntaxError($lineNo, $nameOfID, "Invalid arguments in call");
							}
					}
					
					# Check for a call with the incorrect number of arguments
					if ($tree[$treeIndex + 2] =~ m/expression/)
					{
							#Adjust only two if two lines down is the first expression (this happens for calls with 1 argumentt)
							$treeIndex += 2;
					}
					else
					{
							#Adjust down by three for calls with more than 1 argument
							$treeIndex += 3;
					}
					
					AdjustDepth();
                    
                    CountArgs($nameOfID,$lineNo);
            }
        }
    }
    
    ++$treeIndex;
}










