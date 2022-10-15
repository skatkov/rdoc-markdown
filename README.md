# Rdoc::Markdown
This gem is focused on spitting readable markdown files based on rdoc documentation. It should also come with sqlite database as an index (but this is so far only in plans). 

It is still actively in development and while works as proof of concept, still has some quirks here and there.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add rdoc-markdown

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install rdoc-markdown

## Usage
First thing to do, is to install a gem

`gem install rdoc-markdown`

Then proceed to directory where you want to generate documentation:

`rdoc --format=markdown"

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

## Release
```
gem build rdoc-markdown.gemspec
gem push rdoc-markdown-0.1.2.gem
```
## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/rdoc-markdown. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/rdoc-markdown/blob/master/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the Rdoc::Markdown project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/rdoc-markdown/blob/master/CODE_OF_CONDUCT.md).
