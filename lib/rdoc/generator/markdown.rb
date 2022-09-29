gem 'rdoc'

require 'rdoc/rdoc'
require 'rdoc/generator/json_index'

class RDoc::Generator::Markdown
    RDoc::RDoc.add_generator self

    def initialize(store, options)
        @store = store
        @options = options
    end

    def generate
        binding.irb
    end
end