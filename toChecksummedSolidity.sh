#!/bin/bash

checksummedBytes=$(cast to-checksum "$1")

# Print the checksummed address as a string literal
# This is to interface between bash and solidity.
# For some reason, the solidity deployment script will always cast 
# the result of a direct call to `cast to-checksum` to a lowercase string.
# Printing the bytes as a string literal fixes this.
printf "0"
printf "\x$checksummedBytes"