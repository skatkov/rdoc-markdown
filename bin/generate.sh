#!/bin/sh


rm -r example/
bundle exec rdoc --format=markdown -o example/ --root=test/data/ -D

## convert ruby source into a markdown documentation.
bundle exec rdoc --format=markdown -o example_ruby/ --root=source_ruby/ -D
