#!/bin/bash
pelican content -o output -s pelicanconf.py
cp -r themes/basic/* output/theme
cd output && python -m SimpleHTTPServer
