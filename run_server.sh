#!/bin/bash
pelican content -o output -s pelicanconf.py
cd output && python -m SimpleHTTPServer
