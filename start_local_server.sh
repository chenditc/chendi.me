#!/bin/bash
set -e
set -x
cd $(dirname $0)
open -a "Google Chrome" http://0.0.0.0:4000
jekyll serve --watch -H 0.0.0.0
