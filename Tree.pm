#!/cygdrive/c/Perl/bin/perl -w

use strict;


package Tree;

sub new
{
    my ($class) = @_;
    my $self = {
                data        => undef, 
                parent      => 0, 
                children    => undef
                };
    bless $self, $class;
    return $self;
}

sub data
{
    my ($self, $data) = @_;
    $self->{data} = $data if defined($data);
    return $self->{data};    
}

sub parent
{
    my ($self, $parent) = @_;
    $self->{parent} = $parent if defined($parent);
    return $self->{parent};    
}

sub children
{
    my ($self, $children) = @_;
    $self->{children} = $children if defined($children);
    return $self->{children};    
}

sub print
{
    my ($self) = @_;
    #printf( "Node:\tdata = %s\n\tparent = %s\n\tchildren = %s\n", $self->data,$self->parent, $self->children);
    if (defined($self->data))
    {
        printf( "Node:\tdata = %s\n", $self->data);
    }
    if (defined($self->parent))
    {
        printf( "\tparent = %s\n", $self->parent);
    }
    if (defined($self->children))
    {
        printf( "\tchildren = %s\n", $self->children);
    }

    for (my $Index = 0;defined($self->{children}[$Index]);++$Index)
    {
        $self->{children}[$Index]->print();
    }
}

sub AddChild
{
    my ($self, $child) = @_;
    my @children = $self->{children};
    if(defined($child))
    {
        $child->parent($self);
        
        if(defined($children[0]))
        {
            push(@children, $child);
            $self->{children} = [@children];
        }
        else
        {
            $self->{children} = $child;
        }
    }
   
    return $self->{children};
}

sub PopChild
{
    my ($self) = @_;
    my @children = $self->{children};
    pop(@children);
    $self->{children} = [@children];

    return $self->{children};
}


#my $root = new Tree();
#my $node1 = new Tree();
#my $node2 = new Tree();

#$root->data("root node data");
#$node1->data("node 1 data");
#$node2->data("node 2 data");

#$root->AddChild($node1);
#$root->AddChild($node2);

#$root->print();

1;

