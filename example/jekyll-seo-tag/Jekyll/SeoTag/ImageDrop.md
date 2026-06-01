# Class Jekyll::SeoTag::ImageDrop
<a id="class-jekyll-seotag-imagedrop"></a>

A drop representing the page image The image path will be pulled from:

1. The `image` key if it’s a string

2. The `image.path` key if it’s a hash

3. The `image.facebook` key

4. The `image.twitter` key

### Public Class Methods

#### `new(page: nil, context: nil)`
<a id="method-c-new"></a>

Initialize a new [`ImageDrop`](ImageDrop.md)

page - The page hash (e.g., Page#to\_liquid) context - the Liquid::Context

### Public Instance Methods

#### `path()`
<a id="method-i-path"></a>

Called path for backwards compatability, this is really the escaped, absolute URL representing the page’s image Returns nil if no image path can be determined

#### `to_s()`
<a id="method-i-to_s"></a>

Alias for: [`path`](#method-i-path)
