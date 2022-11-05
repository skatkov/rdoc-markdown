# RDoc-Markdown
RDoc plugin to generate markdown documentation and search index backed by sqlite database.

## Motivation
I'm trying to depend less on software with GUI and use move software that could be used through console. Documentation in markdown format allows me to review documentation in command console, instead of browser or GUI software like DevDocs.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add rdoc-markdown

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install rdoc-markdown

## Usage
RDoc will auto-detect rdoc-markdown plugin. You just need to instruct RDoc to produce markdown output instead of standard HTML through `format` parameter. 

Run following command in directory with ruby source code:

`rdoc --format=markdown`

This will produce a tree of markdown documents and search index in `/doc` folder.

## Development
Biggest issue is testing this locally, but that's not as hard to do these days.

```
gem build rdoc-markdown.gemspec
```

```
gem install <path-to>/rdoc-markdown-0.1.2.gem
```

or you can do the same, but through gemfile:

```
gem 'rdoc-markdown`, path: "../rdoc-markdown/`
```

I have scripted entire process in [rm-reload.sh script](https://github.com/skatkov/gum/blob/master/rm-reload.sh). But it assumes, that you have [gum library](https://github.com/charmbracelet/gum) installed.

## Testing
Testing is not excessive, just verifies that basic functionality is operational. Following command should run entire testsuit:

```
rake test
```

## Release
```
gem build rdoc-markdown.gemspec
gem push rdoc-markdown-0.1.2.gem
```

There is `./publish.sh` script that does that. But it assumes, that you have [gum library](https://github.com/charmbracelet/gum) installed.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/skatkov/rdoc-markdown. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/skatkov/rdoc-markdown/blob/master/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the Rdoc::Markdown project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/skatkov/rdoc-markdown/blob/master/CODE_OF_CONDUCT.md).
