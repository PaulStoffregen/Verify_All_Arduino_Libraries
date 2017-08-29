# Verify All Arduino Libraries

A handful of different boards, each with many different build options, and
hundreds or even thousands of Arduino libraries, many having dozens of
different examples, quickly adds up to far more than anyone can manually
test.

This script randomly compiles Arduino library examples and logs the results
to 3 files, for compiler errors, compiler warnings, and successful compile.
Obviously it can't check if the compiled code actually works on real boards,
but merely making a list of compiler errors and warnings is pretty useful.

Many hard-coded Teensy specific assumptions are built into this script.
Perhaps over time it will gain the ability to find libraries in more
locations and compile against more types of boards having different
boards.txt files installed in various locations.


