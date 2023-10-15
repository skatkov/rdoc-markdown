# class Duck [](#class-Duck) [](#top)
A duck is a [`Waterfowl`](Waterfowl.html) [`Bird`](Bird.html).

Features:

```
bird::

 * speak
 * fly

waterfowl::

 * swim
```
 ## Constants
 | Name | Description |
 | ---- | ----------- |
 | **MAX_VELOCITY[](#MAX_VELOCITY)** | Not documented |
 # Bird overrides
 ## Constants
 | Name | Description |
 | ---- | ----------- |
 | **MAX_VELOCITY[](#MAX_VELOCITY)** | Not documented |
 ## Public Instance Methods
 ### speak() { |speech| ... } [](#method-i-speak)
 [`Duck`](Duck.html) overrides generic implementation.

 # Duck extensions
 ## Constants
 | Name | Description |
 | ---- | ----------- |
 | **MAX_VELOCITY[](#MAX_VELOCITY)** | Not documented |
 ## Attributes
 ### domestic[RW] [](#attribute-i-domestic)
 True for domestic ducks.

 ### rubber[R] [](#attribute-i-rubber)
 True for rubber ducks.

 ## Public Class Methods
 ### new(domestic, rubber) [](#method-c-new)
 Creates a new duck.

 ### rubber_ducks() [](#method-c-rubber_ducks)
 Returns list of all rubber ducks.

 ## Public Instance Methods
 ### useful? -> bool [](#method-i-useful-3F)
 Checks if this duck is a useful one.

 