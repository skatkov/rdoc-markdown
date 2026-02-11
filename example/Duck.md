# Class Duck
<a id="class-Duck"></a>

A duck is a [`Waterfowl`](Waterfowl.md) [`Bird`](Bird.md).

Features:

bird:

- speak
- fly

waterfowl:

- swim

## Bird overrides

### Public Instance Methods

#### `speak() { |speech| ... }`
<a id="method-i-speak"></a>

[`Duck`](Duck.md) overrides generic implementation.

## Duck extensions

### Constants

#### `MAX_VELOCITY`
<a id="MAX_VELOCITY"></a>

Not documented.

### Attributes

#### `domestic` [RW]
<a id="attribute-i-domestic"></a>

True for domestic ducks.

#### `rubber` [R]
<a id="attribute-i-rubber"></a>

True for rubber ducks.

### Public Class Methods

#### `new(domestic, rubber)`
<a id="method-c-new"></a>

Creates a new duck.

#### `rubber_ducks()`
<a id="method-c-rubber_ducks"></a>

Returns list of all rubber ducks.

### Public Instance Methods

#### `useful? -> bool`
<a id="method-i-useful-3F"></a>

Checks if this duck is a useful one.
