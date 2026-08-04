# RDoc-Markdown
RDoc plugin to generate markdown documentation and search index file (CSV).

> [!CAUTION]
> This gem relies on multiple hacks to generate "plausible" markdown documentation. This is **NOT PRODUCTION READY** — use at your own risk.
>
> RDoc maintainers are actively working on markdown support, things will improve with time...

## Motivation
Markdown has become the de facto documentation standard. We can render markdown files on any device, possibly on a thermometer with a screen. And everyone knows markdown...

It's a pity that RDoc can't output a proper markdown file. Somebody has to try to build it.

## Installation

rdoc-markdown requires Ruby 3.3 or newer and RDoc 8 or newer.

Install the gem and add it to your application's Gemfile by executing:

    $ bundle add rdoc-markdown

If Bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install rdoc-markdown


## Usage
RDoc will auto-detect the rdoc-markdown plugin if it is installed. You just need to instruct RDoc to produce markdown output instead of standard HTML through the `format` parameter.

Run the following command in a directory with Ruby source code:

`rdoc --format=markdown`


## Development

```
gem build rdoc-markdown.gemspec
```

```
gem install <path-to>/rdoc-markdown-0.1.2.gem
```

or you can do the same through a Gemfile:

```
gem 'rdoc-markdown', path: "../rdoc-markdown/"
```

## Testing
The following command should run the entire test suite:
```
rake test
```

To validate generated markdown against GitHub Flavored Markdown and check local links/anchors:

```
rake markdown:validate
```

To lint markdown ERB templates:

```
bundle exec rake erb:lint
```

### Generate vendored docs
Use rake tasks to generate markdown output for vendored projects:

`./bin/generate.sh`

or generate only some vendor docs:

```
rake vendor:docs:jekyll_seo_tag
rake vendor:docs:minitest
rake vendor:docs:reverse_markdown
rake vendor:docs:rails
```

Find examples in the [/example](/example/) folder.


## Release

```
gem build rdoc-markdown.gemspec
gem push rdoc-markdown-0.1.2.gem
```

There is a `./bin/publish.sh` script that does that. However, it assumes that you have the [gum library](https://github.com/charmbracelet/gum) installed.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/skatkov/rdoc-markdown. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/skatkov/rdoc-markdown/blob/master/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the RDoc::Markdown project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](https://github.com/skatkov/rdoc-markdown/blob/master/CODE_OF_CONDUCT.md).
