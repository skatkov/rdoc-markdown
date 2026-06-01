# Class Jekyll::SeoTag::Drop
<a id="class-jekyll-seotag-drop"></a>

### Constants

#### `FORMAT_STRING_METHODS`
<a id="FORMAT_STRING_METHODS"></a>

Not documented.

#### `HOMEPAGE_OR_ABOUT_REGEX`
<a id="HOMEPAGE_OR_ABOUT_REGEX"></a>

Not documented.

#### `TITLE_SEPARATOR`
<a id="TITLE_SEPARATOR"></a>

Not documented.

### Public Class Methods

#### `new(text, context)`
<a id="method-c-new"></a>

Not documented.

### Public Instance Methods

#### `author()`
<a id="method-i-author"></a>

A drop representing the page author

#### `canonical_url()`
<a id="method-i-canonical_url"></a>

Not documented.

#### `date_modified()`
<a id="method-i-date_modified"></a>

Not documented.

#### `date_published()`
<a id="method-i-date_published"></a>

Not documented.

#### `description()`
<a id="method-i-description"></a>

Not documented.

#### `image()`
<a id="method-i-image"></a>

Returns a [`Drop`](Drop.md) representing the page’s image Returns nil if the image has no path, to preserve backwards compatability

#### `json_ld()`
<a id="method-i-json_ld"></a>

A drop representing the JSON-LD output

#### `links()`
<a id="method-i-links"></a>

Not documented.

#### `logo()`
<a id="method-i-logo"></a>

Not documented.

#### `name()`
<a id="method-i-name"></a>

rubocop:enable Metrics/CyclomaticComplexity

#### `page_lang()`
<a id="method-i-page_lang"></a>

Not documented.

#### `page_locale()`
<a id="method-i-page_locale"></a>

Not documented.

#### `page_title()`
<a id="method-i-page_title"></a>

Page title without site title or description appended

#### `site_description()`
<a id="method-i-site_description"></a>

Not documented.

#### `site_tagline()`
<a id="method-i-site_tagline"></a>

Not documented.

#### `site_tagline_or_description()`
<a id="method-i-site_tagline_or_description"></a>

Not documented.

#### `site_title()`
<a id="method-i-site_title"></a>

Not documented.

#### `title()`
<a id="method-i-title"></a>

Page title with site title or description appended rubocop:disable Metrics/CyclomaticComplexity

#### `title?()`
<a id="method-i-title-3F"></a>

Should the ‘\<title\>` tag be generated for this page?

#### `type()`
<a id="method-i-type"></a>

Not documented.

#### `version()`
<a id="method-i-version"></a>

Not documented.
