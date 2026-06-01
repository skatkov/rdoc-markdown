# Class Jekyll::SeoTag
<a id="class-jekyll-seotag"></a>

### Constants

#### `MINIFY_REGEX`
<a id="MINIFY_REGEX"></a>

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

#### `VERSION`
<a id="VERSION"></a>

Not documented.

### Attributes

#### `context` [RW]
<a id="attribute-i-context"></a>

Not documented.

### Public Class Methods

#### `new(_tag_name, text, _tokens)`
<a id="method-c-new"></a>

Not documented.

#### `template()`
<a id="method-c-template"></a>

Not documented.

### Public Instance Methods

#### `render(context)`
<a id="method-i-render"></a>

Not documented.
