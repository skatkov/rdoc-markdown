#!/bin/sh


rm -r example/
bundle exec rdoc --format=markdown -o example/ --root=test/data/ -D
