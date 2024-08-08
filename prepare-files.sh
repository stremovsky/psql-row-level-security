#!/bin/bash

mkdir -p .files
cd src
#mkdir -p package; cd package; pip install psycopg2-binary -t .
zip lambda_function.zip lambda_function.py
mv *.zip ../.files/
