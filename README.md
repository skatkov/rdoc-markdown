# RDoc-Markdown
RDoc plugin to generate markdown documentation and search index backed by sqlite database.

> [!CAUTION]
> This should not be used in production. This is a quick "hack" to get to attempt to implement markdown output.
> To reliably produce markdown with rdoc, rdoc itselfs requires improvements in it's internals. 
> Consider this as a demo of a simple looking task that's extremely hard to pull out with rdoc (not the case for yard, though).

## Motivation
Markdown has become the de-facto documentation standard. I heavily rely on Obsidian to render my storage of markdown notes. But markdown is used not just for scribbles, supported is far and wide. We can render markdown file on any device, probably even on thermometer with a screen. But also everyone knows enough markdown to be dangerous (or productive).

It's a pitty that rdoc and yard can't output a proper markdown file. I would like to change that.

## Installation

Install gem and add to application's Gemfile by executing:

    $ bundle add rdoc-markdown

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install rdoc-markdown
## Examples
Find examples in [/examples](/example/) folder. You can regenerate examples by running `./bin/generate.sh`, it will produce examples based on file in `test/data/*` folder.


## Usage
RDoc will auto-detect rdoc-markdown plugin if it was installed. You just need to instruct RDoc to produce markdown output instead of standard HTML through `format` parameter.

Run following command in directory with ruby source code:

`rdoc --format=markdown`

This will produce a tree of markdown documents and search index in `/doc` folder. Every class in library will have it's own markdown file.

## Note on index.csv file
This gem emits index of all markdown files in a index.csv file.

There are decent tools that offer search through structured plain-text files. But my expectation is that nobody will use CSV as an actual search index, but rather import it into something that performs this function better.

In my personal use-case, I use SQLite. All other databases seem to have a good support for CSV imports.

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

## Testing
Following command should run entire testsuit:
```
rake test
```
Testing is not excessive, just verifies that basic functionality is operational.
## Release
```
gem build rdoc-markdown.gemspec
gem push rdoc-markdown-0.1.2.gem
```

There is `./bin/publish.sh` script that does that. But it assumes, that you have [gum library](https://github.com/charmbracelet/gum) installed.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/skatkov/rdoc-markdown. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/skatkov/rdoc-markdown/blob/master/CODE_OF_CONDUCT.md).

## Code of Conduct

Everyone interacting in the Rdoc::Markdown project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/skatkov/rdoc-markdown/blob/master/CODE_OF_CONDUCT.md).
