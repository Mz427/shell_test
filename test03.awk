BEGIN {
    print "Hello, World!" }
{
    print $3 " " $5 }
END {
    print "Goodbye, World!" }