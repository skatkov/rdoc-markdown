<a id="class-jekyll-seotag"></a>
# Class Jekyll::SeoTag

### Constants

<a id="MINIFY_REGEX"></a>
#### `MINIFY_REGEX`
Matches all whitespace that follows either

```
1. A '}', which closes a Liquid tag
2. A '{', which opens a JSON block
3. A '>' followed by a newline, which closes an XML tag or
4. A ',' followed by a newline, which ends a JSON line
```

We will strip all of this whitespace to minify the template We will not strip any whitespace if the next character is a ‘-’

```
so that we do not interfere with the HTML comment at the
very begining
```

<a id="VERSION"></a>
#### `VERSION`
Not documented.

### Attributes

<a id="attribute-i-context"></a>
#### `context` [RW]
Not documented.

### Public Class Methods

<a id="method-c-new"></a>
#### `new(_tag_name, text, _tokens)`
Not documented.

<a id="method-c-template"></a>
#### `template()`
Not documented.

### Public Instance Methods

<a id="method-i-render"></a>
#### `render(context)`
Not documented.
