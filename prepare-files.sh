#!/bin/bash

mkdir -p .files
cd src
zip lambda_function.zip lambda_function.py
mv *.zip ../.files/
