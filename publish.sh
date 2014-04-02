#!/bin/sh
pelican content -o output -s pelicanconf.py

ghp-import output

git push git@github.com:kingheaven/kingheaven.github.io.git gh-pages:master
