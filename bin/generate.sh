#!/bin/sh

set -eu

rm -rf example/
# convert example code into a markdown documentation.
bundle exec rdoc --format=markdown -o example/ --root=test/data/ -D test/data/example.rb
