#!/bin/bash

# make sure that the env variable $SOLC_PATH is already set

# usage compile.sh <solidity version> <file>
$SOLC_PATH"solc-"$1 --bin --evm-version=byzantium --optimize --optimize-runs=200 ../contracts/$2


