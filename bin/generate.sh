#!/bin/sh

rm -r example/
# convert example code into a markdown documentation.
bundle exec rdoc --format=markdown -o example/ --root=test/data/ -D

rm -r example_ruby/
## convert ruby source into a markdown documentation.
bundle exec rdoc --format=markdown -o example_ruby/ --root=source_ruby/ -D --force-output
