<a id="class-duck"></a>
# Class Duck
A duck is a [`Waterfowl`](Waterfowl.md) [`Bird`](Bird.md).

Features:

bird:

- speak
- fly

waterfowl:

- swim

## Bird overrides

### Public Instance Methods

<a id="method-i-speak"></a>
#### `speak() { |speech| ... }`
[`Duck`](Duck.md) overrides generic implementation.

## Duck extensions

### Constants

<a id="MAX_VELOCITY"></a>
#### `MAX_VELOCITY`
Not documented.

### Attributes

<a id="attribute-i-domestic"></a>
#### `domestic` [RW]
True for domestic ducks.

<a id="attribute-i-rubber"></a>
#### `rubber` [R]
True for rubber ducks.

### Public Class Methods

<a id="method-c-new"></a>
#### `new(domestic, rubber)`
Creates a new duck.

<a id="method-c-rubber_ducks"></a>
#### `rubber_ducks()`
Returns list of all rubber ducks.

### Public Instance Methods

<a id="method-i-useful-3F"></a>
#### `useful? -> bool`
Checks if this duck is a useful one.
