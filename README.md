# Rdoc::Markdown
Rdoc Generator plugin to generate markdown documentation and search index as sqlite database that goes along with it.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add rdoc-markdown

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install rdoc-markdown

## Usage
First thing to do, is to install a gem

`gem install rdoc-markdown`

Then proceed to directory where you want to generate documentation:

`rdoc --format=markdown`

Don't forget to append `--debug` to have a bit more information in case thing fail (and they will probably do, because this entire thing is experimental).

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
