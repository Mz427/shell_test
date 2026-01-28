BEGIN {
    printf "Hello, World! "
    printf "NF=%d, NR=%d\n", NF, NR
}
{
    printf "NF=%d, NR=%d; ", NF, NR
    printf "%s\n", $1
    FNR++
}
END {
    printf "Goodbye, World! "
    printf "NF=%d, NR=%d\n", NF, NR
}