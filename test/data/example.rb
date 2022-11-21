##
# === RDoc::Generator::Markdown example.
#
# This example employs various RDoc features to demonstrate
# generator output.
#
# ---
#
# Links:
#
#  1. {Project Home Page}[https://github.com/skatkov/rdoc-markdown)
#  2. {RDoc Documentation}[http://ruby-doc.org/stdlib-2.0.0/libdoc/rdoc/rdoc/RDoc/Markup.html]
#

##
# A mixin for waterfowl creatures.
module Waterfowl
  # Swimming helper.
  def swim
    puts "swimming around"
  end
end

##
# The base class for all birds.
class Bird
  ##
  # Produce some noise.
  #--
  # FIXME: maybe extract this to a base class +Animal+?
  #++
  def speak # :yields: text
    puts "generic tweeting"
    yield "tweet"
    yield "tweet"
  end

  # Fly somewhere.
  #
  # Flying is the most critical feature of birds.
  #
  # :args: direction, velocity
  #
  # :call-seq:
  #   Bird.fly(symbol, number) -> bool
  #   Bird.fly(string, number) -> bool
  #
  # = Example
  #
  #   fly(:south, 70)
  def fly(direction, velocity)
    _fly_impl(direction, velocity)
  end

  def _fly_impl(_direction, _velocity) # :nodoc:
    puts "flying away: direction=#{direction}, velocity=#{velocity}"
  end
end

##
# A duck is a Waterfowl Bird.
#
# Features:
#
#  bird::
#
#    * speak
#    * fly
#
#  waterfowl::
#
#    * swim
class Duck
  extend Animal
  include Waterfowl

  # :section: Bird overrides

  # Duck overrides generic implementation.
  def speak
    speech = quack
    yield speech
  end

  # Implements quacking
  def quack
    "quack"
  end

  private :quack

  # :section: Duck extensions

  # True for domestic ducks.
  attr_accessor :domestic

  # True for rubber ducks.
  attr_reader :rubber

  MAX_VELOCITY = 130 # Maximum velocity for a flying duck.

  ##
  # Global list of all rubber ducks.
  #
  # Use when in trouble.
  @@rubber_ducks = []

  # Returns list of all rubber ducks.
  def self.rubber_ducks
    @@rubber_ducks
  end

  # Creates a new duck.
  def initialize(domestic, rubber)
    @domestic = domestic
    @rubber = rubber
    @@rubber_ducks << self if rubber
  end

  # Checks if this duck is a useful one.
  #
  # :call-seq:
  #   Bird.useful? -> bool
  def useful?
    @domestic || @rubber
  end
end

# Default velocity for a flying duck.
DEFAULT_DUCK_VELOCITY = 70

# Default rubber duck.
#
# *Note:*
#  Global variables are evil, but rubber ducks are worth it.
$default_rubber_duck = Duck.new(false, true)

# Domestic rubber duck.
#
# *Note:*
#  This is weird... Thus not making it global.
domestic_rubber_duck = Duck.new(true, true) # rubocop:disable Lint/UselessAssignment
