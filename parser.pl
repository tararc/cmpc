#!/cygdrive/c/Perl/bin/perl -w
#****************************************************/
#* File: parser.pl                                  */
#* Parser implementation                            */
#* for the C- compiler                              */
#* Cesar Carrasco / Steve Hammond                   */
#****************************************************/

# use strict to make sure our code is up to Perl standards:
use strict;

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


#Original '.cmi' file:
our $filename = $ARGV[0];

# Input token file from scanner:
our $tokenFile = $ARGV[1];

# Check for any flags (-p -s) for print output:
our $printFlag = 0;
if($ARGV[2])
{
    $printFlag = $ARGV[2];
}


#open the token file:
if (!open(TOKEN_FILE, $tokenFile))
{
    # if we can't open the file, kill the program:
	die "Cannot find file $tokenFile \n";
}

# Array and index counter to store all tokens listed in the token file:
our @tokens;
our $tokenIndex = 0;

# Read tokens in token file and store each as an element in an array:
while(my $currentLine = <TOKEN_FILE>)
{
    # Remove newlines:
    chomp($currentLine);
    
    # Add current token to array:
    push(@tokens, $currentLine);
}

# Close token file:
close(TOKEN_FILE);

# Tree structure:
#******************************************************************************
package TreeNode;
use Class::Struct;

struct (
        data            => '$',         # Used to hold syntax data
        parent          => 'TreeNode',  # A pointer to the node's parent
        children        => '@',         # An array of this node's children (any number)
        totalChildren   => '$',         # Number of children belonging to this node
        type            => '$'          # BNF Node type (for internal use)
        );

# Function to create a new tree node:
#******************************************************************************
sub CreateNode #($data)
{
    # Assign input arguments to $data
    my ($data) = @_;
    
    # Create the node and set it's data members
    my $node = new TreeNode;
    $node->data($data);
    $node->totalChildren(-1);   # Records one less than the number of children, used to address last child in an array
    
    # Return the newly created node to the caller
    return $node;
};

# Function to Add a child to a tree node:
#******************************************************************************
sub AddChild #($parentNode, $childNode)
{
    # Assign input arguments
    my($parent, $child) = @_;
    
    # Set the parent/child relationship and update the number of children
    $child->parent($parent);
    $parent->totalChildren($parent->totalChildren + 1);
    $parent->children($parent->totalChildren, $child);

    # Return the child (for internal use)
    return $child;
};

# String for PrintSemanticTree() output:
my $PrintString = "";

# Function to print the tree we are expecting to be processed
# by the sematic analyzer (subject to change):
#******************************************************************************
sub PrintSemanticTree #($tree)
{
    # Assign input arguments
    my ($tree, $depth) = @_;
    
    # Enter this block if the tree has one or zero children
    if($tree->totalChildren <= 0)
    {
        print "$PrintString" . ' ' . $tree->data . "\n";
        
        # Print the child of this node if it has one
        if($tree->totalChildren == 0)
        {
            $PrintString .= $tree->type;
            PrintSemanticTree($tree->children->[0], $depth + 1);
            chop($PrintString);
        }
    }
    
    # Enter this block for trees with two or more children
    else
    {
        # Safeguard: $tree->type variable may not be set properly
        if (defined($tree->type))
        {
            $PrintString .= $tree->type;
        }
        else
        {
            $PrintString .= '-';
        }
        
        # Print all of the children of this tree
        my $totalChildren = $tree->totalChildren;
        for(my $i = 0; $i <= $totalChildren; ++$i)
        {
            PrintSemanticTree($tree->children->[$i], $depth + 1);
        }
        chop($PrintString);
    }
};

# Function to print a tree:
#******************************************************************************
sub PrintParseTree #($tree)
{
    # Assign input arguments
    my ($tree, $depth) = @_;
    
    # Print data about a leaf node, one with no children
    if($tree->totalChildren == -1)
    {
        # Prints a number of tabs equal to its depth
        my $tabs = "-";
        for(my $i = 0; $i <= $depth; ++$i)
        {
            $tabs .= "-";
        }

        print "$tabs" . $tree->data . "\n";
    }
    
    # Enter this block for nodes with any children
    else
    {
        # Recursively print all of this tree's children
        my $totalChildren = $tree->totalChildren;
        for(my $i = 0; $i <= $totalChildren; ++$i)
        {
            PrintParseTree($tree->children->[$i], $depth + 1);
        }
    }
    
};


#Syntax Error Message:
sub SyntaxError
{
    my @tokenError = split(/: /, $_[0]);
    if(@tokenError == 3)
    {
        my $line = $tokenError[0];
        my $type = $tokenError[1];
        my $token = $tokenError[2];

        die "Syntax error on line $line near $token.\n";
    }

};


# Create the Root Node:
my $tree = CreateNode("root node");

# Get the Declaration list:
$tree = Declaration_list();

# Print our tree:
if($printFlag eq "-p")
{
    PrintParseTree($tree, 0);
    print "<<EOF>>";
}
elsif($printFlag eq "-s")
{
    PrintSemanticTree($tree, 0);
    print "<<EOF>>";
}
else
{
    #Do nothing
}



# declaration-list -> declaration-list declaration | declaration
#******************************************************************************
sub Declaration_list
{
    # Create and label our subtree:
    my $tree = CreateNode("declaration_list");
    
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # This is a list of declarations, keep looping while there are declarations to be had
    while($node = Declaration())
    {
        push(@nodes, $node);
        
        # Stop parsing when the end of the file is found
        if($tokens[$tokenIndex] =~ m/^EOF$/)
        {
            last;   
        }
    }
    
    # Loop through every data piece in @nodes, adding them to the root node
    foreach(@nodes)
    {
        AddChild($tree, $_);
    }
    
    # Declaration-lists are represented as 'D' (for internal use)
    $tree->type('D');
    return $tree;
};

# declaration -> var-declaration | fun-declaration
#******************************************************************************
sub Declaration 
{
    my $tree = CreateNode("declaration");
    my $node;
    
    # Attempts to assign this Declaration as a variable declaration
    if($node = Var_declaration())
    {
        # Declarations are represented by 'd' (for internal use)
        AddChild($tree,$node);
        $tree->type('d');
        return $tree;
    }
    
    # If it is not a Var_decl check if it is a Function_declaration
    elsif($node = Fun_declaration())
    {
        # Declarations are represented by 'd' (for internal use)
        $tree->type('d');
        AddChild($tree,$node);
        return $tree;
    }
    
    # If it was neither type of declaration, there was a syntax error in the code
    else
    {
        #print "Invalid Token: declaration -> var-declaration | fun-declaration\n";
        return;
    }
};

# var-declaration -> type-specifier ID ; | type-specifier ID [ NUM ] ;
#******************************************************************************
sub Var_declaration  
{
    # Create and label our subtree:
    my $tree = CreateNode("var-declaration");
    
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # Attempts to assign this node as a Type_specifier
    if($node = Type_specifier())
    {
        push(@nodes, $node);
        
        # Error checking, a series of checks to make sure there was no syntax error
        if($tokens[$tokenIndex] =~ m/$ID/)
        {
            my $node = CreateNode("$1$2$3");
            push(@nodes, $node);
            ++$tokenIndex;
			
			# Check for semi colon, not an array variable
            if($tokens[$tokenIndex] =~ m/$SEMICOLON/)
            {
                ++$tokenIndex;

                foreach(@nodes)
                {
                    AddChild($tree, $_);
                }
                
                $tree->type('V');
                return $tree;
            }
            
            # If there was no semi colon keep going, it may be an array declaration
            elsif($tokens[$tokenIndex] =~ m/$LBRACKET/)
            {
                my $node = CreateNode("$1$2$3");
				push(@nodes, $node);
                ++$tokenIndex;
                
                # Error checking, make sure the syntax for an array declaration is correct
                if($tokens[$tokenIndex] =~ m/$NUM/)
                {
                    my $node = CreateNode("$1$2$3");
					push(@nodes, $node);
                    ++$tokenIndex;
                    
                    # More error checking
                    if($tokens[$tokenIndex] =~ m/$RBRACKET/)
                    {
                        my $node = CreateNode("$1$2$3");
						push(@nodes, $node);
                        ++$tokenIndex; 
                        
                        # Even more error checking
                        if($tokens[$tokenIndex] =~ m/$SEMICOLON/)
                        {
                            ++$tokenIndex;

                            # Add the data found (brackets and so forth) as children to this node
                            foreach(@nodes)
                            {
                                AddChild($tree, $_);
                            }
                            
                            # Variables are represented by 'V' (for internal use)
                            $tree->type('V');
                            return $tree;
                        }
                    }
                }
                
                SyntaxError($tokens[$tokenIndex]);;
            }
            
            # If the syntax was wrong, this is not a Var_decl, return nothing
            else
            {
                #we might have a fun-declaration here
                $tokenIndex -= 2;
                return;
            }
        }  
    }
    # If the syntax was wrong, this was not a Var_decl, return nothing
    else
    {
        return;
    }   

};

# type-specifier -> int | void
#******************************************************************************
sub Type_specifier
{
	my $node;

    # Check if the token under inspection specifies an int
    if($tokens[$tokenIndex] =~ m/$INT/)
    {
		my $node = CreateNode("$1$2$3");
        ++$tokenIndex;
        
        # Type-Specifiers are represented by 't'
        $node->type('t');
        return $node;
    }
    
    # If the token was not an int, check if it was a void
    elsif($tokens[$tokenIndex] =~ m/$VOID/)
    {
		my $node = CreateNode("$1$2$3");
        ++$tokenIndex; 
        
        # Type-Specifiers are represented by 't'
        $node->type('t');
        return $node;
    }
    
    # If it was not an int or a void, return nothing
    else
    {
        return;
    }  
};

# fun-declaration -> type-specifier ID ( params ) compound-stmt
#******************************************************************************
sub Fun_declaration 
{
    # Create and label our subtree:
	my $tree = CreateNode("fun-declaration");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # Attempt to locate the type specifier of a function declaration
    if($node = Type_specifier())
    {
        push(@nodes, $node);
        
        # Attampt to locate the ID of a function
        if($tokens[$tokenIndex] =~ m/$ID/)
        {
            my $node = CreateNode("$1$2$3");
			push(@nodes, $node);
            ++$tokenIndex;
                  
            # Attempt to locate the left parenthesis
            if($tokens[$tokenIndex] =~ m/$LPAREN/)
            {
                ++$tokenIndex;
                
                # Attempt to locate parameters within the parentheses
                if($node = Params())
                {
                    push(@nodes, $node);

                    # Attempt to locate the right parenthesis
                    if($tokens[$tokenIndex] =~ m/$RPAREN/)
                    {
                        ++$tokenIndex;
                        
                        if($node = Compound_stmt())
                        {
				            push(@nodes, $node);
				            
                            foreach(@nodes)
                            {
                                AddChild($tree, $_);
                            }
                            
                            # Fun-Declarations are represented by 'F'
                            $tree->type('F');
                            return $tree;
                        } 
                    }
                } 
            }  
        }
        
        SyntaxError($tokens[$tokenIndex]);;
    }

    # If the proper pieces were not found, this is obviously not a function declaration
    else
    {
        return;
    } 
   
};

# params -> param-list | void
#******************************************************************************
sub Params  
{
    # Create and label our subtree:
	my $tree = CreateNode("params");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # Attempt to find a param_list
    if($node = Param_list())
    {
        AddChild($tree, $node);
        
        # Paramses are represented by 'R' (for internal use)
        $tree->type('R');
        return $tree;
    }
    
    # If there was no param-list, check for the void keyword
    elsif($tokens[$tokenIndex] =~ m/$VOID/)
    {
		my $node = CreateNode("$1$2$3");
        AddChild($tree, $node);
        ++$tokenIndex;
        
        # Paramses are represented by 'R' (for internal use)
        $tree->type('R');
        return $tree;
    }
    
    # If there was no params found, return nothing
    else
    {
        return;
    }
};

# param-list -> param-list , param | param
#******************************************************************************
sub Param_list  
{
    # Create and label our subtree:
	my $tree = CreateNode("param-list");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # pull params out of the param-list,
    while($node = Param())
    {
        push(@nodes, $node);
        
        # Check if there is a comma after the last param pulled
        if($tokens[$tokenIndex] =~ m/$COMMA/)
        {
            ++$tokenIndex; 
        }
        
        # If there was no comma, there are no more params, stop looking for them 
        else
        {
            # if the next token is a Param, we can error for no COMMA:
            if(Param())
            {
                SyntaxError($tokens[$tokenIndex]);;
            }
            else
            {
                foreach(@nodes)
                {
                    AddChild($tree, $_);
                }
                
                # param-lists are represented by 'r' (for internal use)
                $tree->type('r');
                return $tree;
            }
        }
    }
    
    # If there were no params found, return nothing
    return;
};

# param -> type-specifier ID | type-specifier ID [ ]
#******************************************************************************
sub Param  
{
    # Create and label our subtree:
	my $tree = CreateNode("param");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # Attempt to pull a Type_specifier
    if($node = Type_specifier())
    {
        push(@nodes, $node);
        
        # If there was a type specifier, look for an ID
        if($tokens[$tokenIndex] =~ m/$ID/)
        {
            my $node = CreateNode("$1$2$3");
            push(@nodes, $node);
            ++$tokenIndex;
            
            # If ther was a good ID, look for a left brakcet (checking for an array)
            if($tokens[$tokenIndex] =~ m/$LBRACKET/)
            {
                my $node = CreateNode("$1$2$3");
                push(@nodes, $node);
                ++$tokenIndex;
                
                # If ther was a left bracket, check for a right bracket
                if($tokens[$tokenIndex] =~ m/$RBRACKET/)
                {
                    my $node = CreateNode("$1$2$3");
                    push(@nodes, $node);
                    ++$tokenIndex;
                    
                    foreach(@nodes)
                    {
                        AddChild($tree, $_);
					}
					
					# Params are represented by 'p' (for internal use)
					$tree->type('p');
                    return $tree;
                }
                
                SyntaxError($tokens[$tokenIndex]);;
            }
            
            # If there was no brackets, it must just be a variable
            else
            {
				foreach(@nodes)
                {
                    AddChild($tree, $_);
				}

                # Params are represented by 'p' (for internal use)
                $tree->type('p');
                return $tree;
            }
        }
        else
        {
            # This must not be a Param... maybe its a 'void' param!
            --$tokenIndex;
        }
    }
     
    return;   
};

# compound-stmt -> { local-declarations statement-list }
#******************************************************************************
sub Compound_stmt  
{
    # Create and label our subtree:
	my $tree = CreateNode("compound-stmt");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
  
    # Check that our compound statement starts with a left brace
    if($tokens[$tokenIndex] =~ m/$LBRACE/)
    {
        ++$tokenIndex;
        
        # Check for local declarations, this may be empty
        if($node = Local_declarations())
        {
            push(@nodes, $node);
        }
        
        # Make sure there is a Statement_list, this is required
        if($node = Statement_list())
        {
            push(@nodes, $node);
            
            # Make sure the next token is a closing brace
            if($tokens[$tokenIndex] =~ m/$RBRACE/)
            {
                ++$tokenIndex;
                
                foreach(@nodes)
                {
                    AddChild($tree, $_);
                }
                
                # Compound_statements are represented by 'C' (for internal use)
                $tree->type('C');
                return $tree;
            }
            
            SyntaxError($tokens[$tokenIndex]);;
        }
        
        # if there was no Statement list, see if it was just an empty block
        else
        {
            # See if the next token was a closing brace
            if($tokens[$tokenIndex] =~ m/$RBRACE/)
            {
                #we have a legal empty block
                ++$tokenIndex;
                # Compound_statements are represented by 'C' (for internal use)
                $tree->type('C');
                return $tree;
            }

            SyntaxError($tokens[$tokenIndex]);;
        }
    }
    
    # If there was no opening brace, this is not a compound statement, return nothing
    else
    {
        return;
    }   
};

# local-declarations -> local-declarations var-declarations | empty
#******************************************************************************
sub Local_declarations  
{
    # Create and label our subtree:
	my $tree = CreateNode("local-declarations");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # There may be any number of local declarations, loop through until you have found them all
    while($node = Var_declaration())
    {
		push(@nodes, $node);
    }

    # Add the declarations to the tree
    foreach(@nodes)
    {
        AddChild($tree, $_);
    }
     
    # if empty, $tree will have no children:
    if($tree->totalChildren == -1)
    {
        return;
    }
    
    # If there were any children, return it the tree
    else
    {
        # Local_declarations are represented by 'L' (for internal use)
        $tree->type('L');
        return $tree;
    }
};

# statement-list -> statement-list statement | empty
#******************************************************************************
sub Statement_list  
{
    # Create and label our subtree:
	my $tree = CreateNode("statement-list");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # Grab statements as long as there are any to grab
    while($node = Statement())
    {
		push(@nodes, $node);
    }

    # Add those statements to the tree
    foreach(@nodes)
    {
        AddChild($tree, $_);
    }
    
    # if empty, $tree will have no children:
    if($tree->totalChildren == -1)
    {
        return;
    }
    
    # Return the tree of statements if there were any
    else
    {
        # Statement-lists are represented by 'S' (for internal use)
        $tree->type('S');
        return $tree;
    }
};

# statement -> expression-stmt | compound-stmt | selection-stmt | iteration-stmt | return-stmt
#******************************************************************************
sub Statement  
{
    # Create and label our subtree:
	my $tree = CreateNode("statement");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;

    # Attempt to grab an expression statement
    if($node = Expression_stmt())
    {
        # Set the node and return it if it was an expression statement
        AddChild($tree, $node);
        # Statements are represented by 's' (for internal use)
        $tree->type('s');
        return $tree;
    }
    
    # If it was not an expression statement, attempt to grab a compound statement
    elsif($node = Compound_stmt())
    {
        AddChild($tree, $node);
        # Statements are represented by 's' (for internal use)
        $tree->type('s');
        return $tree;
    }
    
    # If it was not a compound statement, attempt to grab a selection statement
    elsif($node = Selection_stmt())
    {
        AddChild($tree, $node);
        # Statements are represented by 's' (for internal use)
        $tree->type('s');
        return $tree;
    }
    
    # If it was not a selection statement, attempt to grab an insertion statement
    elsif($node = Iteration_stmt())
    {
        AddChild($tree, $node);
        # Statements are represented by 's' (for internal use)
        $tree->type('s');
        return $tree;
    }
    
    # If it was not an insertion statement, attempt to grab a return statement
    elsif($node = Return_stmt())
    {
        AddChild($tree, $node);
        $tree->type('s');
        return $tree;
    }
    
    # If there was no valid statement found, return nothing
    else
    {
        return;
    }
};

# expression-stmt -> expression ; | ;
#******************************************************************************
sub Expression_stmt  
{
    # Create and label our subtree:
	my $tree = CreateNode("expression-stmt");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;

    # Attempt to find an expression
    if($node = Expression())
    {
        push(@nodes, $node);
    }
    
    # If there was no expression, skip it, check for a semicolon
    if($tokens[$tokenIndex] =~ m/$SEMICOLON/)
    {
        ++$tokenIndex;
        
        foreach(@nodes)
        {
            AddChild($tree, $_);
        }
        
        # Expression_statements are represented by 'E' (for internal use)
        $tree->type('E');
        return $tree;
    }
    
    # If no semicolon was found this was not an expression statement, return nothing
    else
    {
        return;
    }
};

# selection-stmt -> if ( expression ) statement | if ( expression ) statement else statement
#******************************************************************************
sub Selection_stmt  
{
    # Create and label our subtree:
	my $tree = CreateNode("selection-stmt");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
	
	# See if the next token to examine is the IF keyword
    if($tokens[$tokenIndex] =~ m/$IF/)
    {
        my $node = CreateNode("$1$2$3");
        push(@nodes, $node);
        ++$tokenIndex;
        
        # See if the next token is an opening parenthesis
        if($tokens[$tokenIndex] =~ m/$LPAREN/)
        {
            ++$tokenIndex;
            
            # Attempt to find an expression inside these parenthesis
            if($node = Expression())
            {
                push(@nodes, $node);
                
                # After the expression, attempt to find a closing parenthesis
                if($tokens[$tokenIndex] =~ m/$RPAREN/)
                {
                    ++$tokenIndex;      
                    
                    if($node = Statement())
                    {
                        push(@nodes, $node);
                        
                        # See if there is an ELSE statement after this IF
                        if($tokens[$tokenIndex] =~ m/$ELSE/) 
                        {
                            ++$tokenIndex;
                            
                            if($node = Statement())
                            {
                                push(@nodes, $node);
                            }
                        }

                        # Add all the appropriate children if it was a valid statement
                        foreach(@nodes)
						{
                            AddChild($tree, $_);
                        }

                        # Selection statements are represented by 'I' (for internal use)
                        $tree->type('I');
                        return $tree;
                    }
                }
            }
        }
        
        SyntaxError($tokens[$tokenIndex]);;
    }
    
    # If this was not a valid selection statement return nothing
    return;
};

# iteration-stmt -> while ( expression ) statement
#******************************************************************************
sub Iteration_stmt  
{
    # Create and label our subtree:
	my $tree = CreateNode("iteration-stmt");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # See if next token if a WHILE statement
    if($tokens[$tokenIndex] =~ m/$WHILE/) 
    {
        my $node = CreateNode("$1$2$3");
        push(@nodes, $node);
        ++$tokenIndex;
        
        # See if the next token is an opennig parenthesis
        if($tokens[$tokenIndex] =~ m/$LPAREN/)
        {
            ++$tokenIndex;
            
            if($node = Expression())
            {
                push(@nodes, $node);
                
                # Check if the next token is a closing parenthesis
                if($tokens[$tokenIndex] =~ m/$RPAREN/)
                {
                    ++$tokenIndex;      
                    
                    # Attempt to grab a statement for this while loop
                    if($node = Statement())
                    {
                        push(@nodes, $node);
                        
                        foreach(@nodes)
                        {
                            AddChild($tree, $_);
                        }
                        
                        # Iteration statements are represented by 'i' (for internal use)
                        $tree->type('i');
                        return $tree;
                    }
                }
            }
        }
        
        SyntaxError($tokens[$tokenIndex]);;
    }

    # If this was not a valid iteration statement, return nothing
    return;
};

# return-stmt -> return ; | return expression ;
#******************************************************************************
sub Return_stmt  
{
    # Create and label our subtree:
	my $tree = CreateNode("return-stmt");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # See if the next token is the RETURN keyword
    if($tokens[$tokenIndex] =~ m/$RETURN/) 
    {
        my $node = CreateNode("$1$2$3");
        push(@nodes, $node);
        ++$tokenIndex;
        
        # Attempt to grab an expression
        if($node = Expression())
        {
            push(@nodes, $node);
        }
        
        # If there was no expression, see if the next token is a semi colon symbol
        if($tokens[$tokenIndex] =~ m/$SEMICOLON/)
        {
            ++$tokenIndex;
            
            foreach(@nodes)
            {
                AddChild($tree, $_);
            }
  
            # return statements are represented by 'U' (for internal use)
            $tree->type('U');
            return $tree;
        }
        
        SyntaxError($tokens[$tokenIndex]);;
    }

    return;
};

# expression -> var = expression | simple-expression
#******************************************************************************
sub Expression  
{
    # Create and label our subtree:
	my $tree = CreateNode("expression");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
	
	# In this special case, make a copy of the token index (it may get lost)
    my $prevTokenIndex = $tokenIndex;
    
    # Attempt to grab a Var for a child, they make good children, grow up big an strong, always fly straight, raise em' right and they might become a doctor... or a lawyer
    if($node = Var())
    {
		push(@nodes, $node);

        # See if the next token is the assignment symbol
        if($tokens[$tokenIndex] =~ m/$ASSIGN/)
        {
            my $node = CreateNode("$1$2$3");
            push(@nodes, $node);
            ++$tokenIndex;
            
            # Attempt to grab an expression as a child
            if($node = Expression())
            {
                push(@nodes, $node);

                foreach(@nodes)
                {
                    AddChild($tree, $_);
                }
                
                # Expressions are represented by 'e' (for internal use)
                $tree->type('e');
                return $tree;
            }
            
            SyntaxError($tokens[$tokenIndex]);;
        }
        
        # If there was no assign statement, check for simple expressions
        else
        {
            #Since we checked tokens for var, we better reset our token position:
            $tokenIndex = $prevTokenIndex;					
			pop(@nodes);
			
			# Attempt to grab a simple expression
            if($node = Simple_expression())
            {
                push(@nodes, $node);
                
                # Add the accumulated nodes as this tree's children
                foreach(@nodes)
                {
                    AddChild($tree, $_);
                }
                
                # Expression are represented by 'e' (for internal use)
                $tree->type('e');
                return $tree;
            }
        }
    }
    
    # If this was not a var, attempt to grab a simple expression
    elsif($node = Simple_expression())
    {
        AddChild($tree, $node);
        
        # Expressions are represented by 'e' (for internal use)
        $tree->type('e');
        return $tree;
    }
    
    # If this was not a var or a simple expression, it is not an expression, return nothing
    else
    {
        return;
    }
    
    # This part of the code should never be reached
    return;

};

# var -> ID | ID [ expression ]
#******************************************************************************
sub Var  
{
    # Create and label our subtree:
	my $tree = CreateNode("var");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # See if the next token is an ID
    if($tokens[$tokenIndex] =~ m/$ID/)
    {
        my $node = CreateNode("$1$2$3");
        push(@nodes, $node);
        ++$tokenIndex;       
        
        # If there was an ID, see if there are square brackets, it may be an array
        if($tokens[$tokenIndex] =~ m/$LBRACKET/)
        {
            my $node = CreateNode("$1$2$3");
            push(@nodes, $node);
            ++$tokenIndex;

            # Attempt to grab an expression if opening square brackets were found
            if($node = Expression())
            {
                push(@nodes, $node);
                
                # See if the next token is a closing square bracket
                if($tokens[$tokenIndex] =~ m/$RBRACKET/)
                {
                    my $node = CreateNode("$1$2$3");
                    push(@nodes, $node);
                    ++$tokenIndex;

                    foreach(@nodes)
                    {
                        AddChild($tree, $_);
                    }

                    # Vars are represented by 'v' (for internal use)
                    $tree->type('v');
                    return $tree;
                }               
            }
            
            SyntaxError($tokens[$tokenIndex]);;
        }
        
        # If there were no brackets found, execute this code, it may still be valid code
        else
        {
            # If the current token is a LPAREN '(' this is not a 'var'... its a 'call'!
            if($tokens[$tokenIndex] =~ m/$LPAREN/)
            {
                --$tokenIndex;
                pop(@nodes);
                return;
            }
            
            # If the next token is not an opening parenthesis, execute this code, it is a var
            else
            {
                foreach(@nodes)
                {
                    AddChild($tree, $_);
                }
                
                # Vars are represented by 'v' (for internal use)
                $tree->type('v');
                return $tree;
            }
        }
    }

    # This part of the code should not be reached
    return;
};

# simple-expression -> additive-expression relop additive-expression | additive-expression
#******************************************************************************
sub Simple_expression  
{
    # Create and label our subtree:
	my $tree = CreateNode("simple-expression");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
	
	# Attempt to grab an additive expression
    if($node = Additive_expression())
    {   
        push(@nodes, $node);
        
        # Attempt to grab a relop
        if($node = Relop())
        {
            push(@nodes, $node);
            
            # Attempt to grab an additive expression
            if($node = Additive_expression())
            {
				push(@nodes, $node);
                
                # If everything worked out, add the children to this tree
                foreach(@nodes)
                {
                    AddChild($tree, $_);
                }
                
                # Simple_expressions are represented by 'X' (for internal use)
                $tree->type('X');
                return $tree;
            }
        }
        
        # If there was no relop, but there was an additive expression, it is still valid
        else
        {
			foreach(@nodes)
            {
                AddChild($tree, $_);
            }
            
            # Simple expressions are represented by 'X'
            $tree->type('X');
            return $tree;
        }
    }

    # If ther ewas no additive expression, this is not a valid node, return nothing
    return;

};

# relop -> <= | < | > | >= | == | !=
#******************************************************************************
sub Relop  
{
    # Create and label our subtree:
	my $tree = CreateNode("relop");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
	
	# Do a regular expression check for every type of relop, checking the next token
    if(($tokens[$tokenIndex] =~ m/$LTEQ/) || ($tokens[$tokenIndex] =~ m/$LT/) || ($tokens[$tokenIndex] =~ m/$GT/) 
    || ($tokens[$tokenIndex] =~ m/$GTEQ/) || ($tokens[$tokenIndex] =~ m/$EQ/) || ($tokens[$tokenIndex] =~ m/$NOTEQ/))
    {
        my $node = CreateNode("$1$2$3");
        AddChild($tree, $node);
        ++$tokenIndex;
        
        # Relops are represented by 'o' (for internal use)
        $tree->type('o');
        return $tree;
    }
    
    # If there was no type of relop found, return nothing
    else
    {
        return;
    }
};

# additive-expression -> additive-expression addop term | term
#******************************************************************************
sub Additive_expression  
{
    # Create and label our subtree:
	my $tree = CreateNode("additive-expression");
	
    # Array to store neighboring op nodes:
    my @opNodes;
    my $opNode;
    
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # Attempt to find a term
    if($node = Term())
    {
        push(@nodes, $node);

        # Iteratively look for addops, checking for a term between every one
        while($opNode = Addop())
        {
            push(@opNodes, $opNode);
            
            # Attempt to grab terms between addops
            if($node = Term())
            {
                push(@nodes, $node);
            }
        }
        
        # Iteratively add terms and addops as children
        while(@opNodes)
        {
            $opNode = shift(@opNodes);
            $node = shift(@nodes);
            AddChild($opNode, $node);
            
            if($node = shift(@nodes))
            {
                AddChild($opNode, $node);
                push(@nodes, $opNode);
            }
            else
            {
               # ????    
            }
        }
        
        foreach(@nodes)
        {
            AddChild($tree, $_);
        }
        
        # Additive expressions are represented by 'A' (for internal use)
        $tree->type('A');
        return $tree;
    }
    return;
};

# addop -> + | -
#******************************************************************************
sub Addop  
{
    # Create and label our subtree:
	my $tree = CreateNode("addop");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
	
	# See if the next token is a '+' or '-'
    if(($tokens[$tokenIndex] =~ m/$PLUS/) || ($tokens[$tokenIndex] =~ m/$MINUS/))
    {
        my $node = CreateNode("$1$2$3");
        AddChild($tree, $node);
        ++$tokenIndex;
        
        # Addops are respresented by 'a' (for internal use)
        $tree->type('a');
        return $tree;
    }
    
    # If the token is not a '+' or '-' it is not a valid addop, return nothing
    else
    {
        return;
    }      
};

# term -> term mulop factor | factor
#******************************************************************************
sub Term  
{
    # Create and label our subtree:
	my $tree = CreateNode("term");
	
    # Array to store neighboring op nodes:
    my @opNodes;
    my $opNode;
    
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # Attempt to grab a factor
    if($node = Factor())
    {
        push(@nodes, $node);

        # Iteratively pull mulops, grabbing another factor after every mulop
        while($opNode = Mulop())
        {
            push(@opNodes, $opNode);
            
            if($node = Factor())
            {
                push(@nodes, $node);
            }
        }
        
        # Iteratively create nodes to add to the tree
        while(@opNodes)
        {
            $opNode = shift(@opNodes);
            $node = shift(@nodes);
            AddChild($opNode, $node);
            
            if($node = shift(@nodes))
            {
                AddChild($opNode, $node);
                push(@nodes, $opNode);
            }
            else
            {
               # ????    
            }
        }
        
        foreach(@nodes)
        {
            AddChild($tree, $_);
        }
        
        # Terms are represented by 'T'
        $tree->type('T');
        return $tree;
    }
    
    # If there is no factor, this is not a valid term, return nothing
    return;

};

# mulop -> * | /
#******************************************************************************
sub Mulop  
{
    # Create and label our subtree:
	my $tree = CreateNode("mulop");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
	
	# See if the next token if a '*' or '/'
    if(($tokens[$tokenIndex] =~ m/$TIMES/) || ($tokens[$tokenIndex] =~ m/$DIVIDE/))
    {
        my $node = CreateNode("$1$2$3");
        AddChild($tree, $node);
        ++$tokenIndex;
        
        # Mulops are represented by 'm' (for internal use)
        $tree->type('m');
        return $tree;
    }

    # If the next token is not a '*' or a '/' it is not a valid mulop, return nothing
    else
    {
        return;
    }       
};

# factor -> ( expression ) | var | call | NUM
#******************************************************************************
sub Factor  
{
    # Create and label our subtree:
	my $tree = CreateNode("factor");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # See if the next token is an opening parenthesis
    if($tokens[$tokenIndex] =~ m/$LPAREN/)
    {
        ++$tokenIndex;
        
        # Attempt to grab an expression
        if($node = Expression())
        {
            push(@nodes, $node);
            
            # See if the next token if a closing parenthesis
            if($tokens[$tokenIndex] =~ m/$RPAREN/)
            {
                ++$tokenIndex;
                
                foreach(@nodes)
                {
                    AddChild($tree, $_);
                }
                
                # Factors are represented by 'F' (for internal use)
                $tree->type('F');
                return $tree;
            }
        }
        
        SyntaxError($tokens[$tokenIndex]);;
    }
    
    # If the next token is not a parenthesis, attempt to grab a Var
    elsif($node = Var())
    {
        AddChild($tree, $node);
        
        # Factors are represented by 'F' (for internal use)
        $tree->type('F');
        return $tree;
    }
    
    # If it is not a Var, see if it is a Call
    elsif($node = Call())
    {
        AddChild($tree, $node);
        
        # Factors are represented by 'F' (for internal use)
        $tree->type('F');
        return $tree;
    }
    
    # If it was not any of the above, see if the next token is a number
    elsif($tokens[$tokenIndex] =~ m/$NUM/)
    {
        my $node = CreateNode("$1$2$3");
        AddChild($tree, $node);
        ++$tokenIndex;
        
        # Factors are represented by 'F' (for internal use)
        $tree->type('F');
        return $tree;
    }
    
    # If nothing was valid, this is not a factor, return nothing
    else
    {
        return;
    }
};

# call -> ID ( args )
#******************************************************************************
sub Call  
{
    # Create and label our subtree:
	my $tree = CreateNode("call");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
	
	# See if the next token is an ID
    if($tokens[$tokenIndex] =~ m/$ID/)
    {
        my $node = CreateNode("$1$2$3");
        push(@nodes, $node);
        ++$tokenIndex;           
 
        # See if the next token if an opening parenthesis
        if($tokens[$tokenIndex] =~ m/$LPAREN/)
        {
            ++$tokenIndex;
            
            # Attempt to grab args
            if($node = Args())
            {
                push(@nodes, $node);
            }
            
            # If there were no args, that is valid, check for a closing parenthesis
            if($tokens[$tokenIndex] =~ m/$RPAREN/)
            {
                ++$tokenIndex;
                
                foreach(@nodes)
                {
                    AddChild($tree, $_);
                }
                
                # Calls are represented by 'c' (for internal use)
                $tree->type('c');
                return $tree;
            }
            
            SyntaxError($tokens[$tokenIndex]);;
        }
    }
    
    # If of those tokens were invalid, this is not a valid call, return nothing
    else
    {
        # need to consider if only part of the 'call' is found
        return;
    }
};

# args -> arg-list | empty
#******************************************************************************
sub Args 
{
    # Create and label our subtree:
	my $tree = CreateNode("args");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # Attempt to grab an Arg-list
    if($node = Arg_list())
    {
        AddChild($tree, $node);
        
        # Arg-lists are represented by 'G' (for internal use)
        $tree->type('G');
        return $tree;
    }
    
    # If ther was no Arg-list, return nothing
    else
    {
        return;   # empty
    }
        
};

# arg-list -> arg-list , expression | expression
#******************************************************************************
sub Arg_list  
{
    # Create and label our subtree:
	my $tree = CreateNode("arg-list");
	
    # Array to store neighboring nodes:
    my @nodes;
    my $node;
    
    # Iteratively attempt to grab expression
    while($node = Expression())
    {
        push(@nodes, $node);
		
		# See if there is a comma after the expression
        if($tokens[$tokenIndex] =~ m/$COMMA/)
        {
            ++$tokenIndex; 
        }
        
        # If there is no comma, there are no more expression to grab
        else
        {
            # check for a syntax error (missing comma)
            if(Expression())
            {
                SyntaxError($tokens[$tokenIndex]);;
            }
       
            last;
        }
    }

    foreach(@nodes)
    {
        AddChild($tree, $_);
    }
    
    # if empty, $tree will have no children:
    if($tree->totalChildren == -1)
    {
        return;
    }
    
    else
    {
        # Arg-lists are represented by 'g' (for internal use)
        $tree->type('g');
        return $tree;
    }
  
};

