// { expected = "tabs" }

/*
This comment
    has
        been
    indented
using
    a
        series
    of
spaces.
Nevertheless,
    this
    should
        not
        interfere
    with
    guess-indent.
*/

// And
    // Now
// Let's
    // Do
    // The

// same
    
    // using
        // some
    // inline
// comments.



// ------------------------------------------------------------------------- //

#include <stdio.h>
int main(int argc, char *argv[]) {
	printf("This code has been indented using tabs.\n");
	printf("That's why guess-indent should detect tabs.\n");
	return 0;
}

