# Test Data

The following directories contain various files that are used to check if
guess-indent can properly determine how they are indented.

Some of them are specifically hand crafted for this, others are just random
files that I found on GitHub that are in the public domain (eg. licenced
under WTFPL).

## Format

The first line of each file should contain a valid lua table containing the
following values:

```lua
{
	expected = int | "tabs",  -- The expected indentation style
	disabled = false,  -- Set to true if this file should be ignored
}
```
