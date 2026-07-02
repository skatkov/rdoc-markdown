<a id="class-jekyll-seotag-authordrop"></a>
# Class Jekyll::SeoTag::AuthorDrop
A drop representing the current page’s author

Author name will be pulled from:

1. The page’s `author` key

2. The first author in the page’s `authors` key

3. The `author` key in the site config

If the result from the name search is a string, we’ll also check for additional author metadata in `site.data.authors`

### Public Class Methods

<a id="method-c-new"></a>
#### `new(page: nil, site: nil)`
Initialize a new [`AuthorDrop`](AuthorDrop.md)

page - The page hash (e.g., Page#to\_liquid) site - The Jekyll::Drops::SiteDrop

### Public Instance Methods

<a id="method-i-name"></a>
#### `name()`
[`AuthorDrop#to_s`](AuthorDrop.md#method-i-to_s) should return name, allowing the author drop to safely replace `page.author`, if necessary, and remain backwards compatible

<a id="method-i-to_s"></a>
#### `to_s()`
Alias for: [`name`](#method-i-name)

<a id="method-i-twitter"></a>
#### `twitter()`
Not documented.
