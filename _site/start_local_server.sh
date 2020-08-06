#!/bin/bash
set -e
set -x
cd $(dirname $0)
jekyll serve --watch -H 0.0.0.0
