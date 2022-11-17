#!/bin/sh


rm -r example/
bundle exec rdoc --format=markdown --markup=markdownrdoc --format=markdown --markup=markdown -o example/ --root=test/data/
