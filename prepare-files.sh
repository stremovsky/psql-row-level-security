#!/bin/bash

mkdir -p .files
cd src
#mkdir -p package; cd package; pip install psycopg2-binary -t .
zip -r lambda_function.zip *
mv *.zip ../.files/
