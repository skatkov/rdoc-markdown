#!/bin/sh

gem build rdoc-markdown.gemspec
GEM=$(gum choose $(ls *.gem))

gum confirm "Publish $GEM?" && gem push $GEM
