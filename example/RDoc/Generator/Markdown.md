# class RDoc::Generator::Markdown [](#class-RDoc::Generator::Markdown) [](#top)


  
  
  
## Constants
 | Name | Description |
 | ---- | ----------- |
    
 | **TEMPLATE_DIR[](#TEMPLATE_DIR)** |  Defines a constant for directory where templates could be found

  |
    
  
  
## Attributes
    
### base_dir[R] [](#attribute-i-base_dir)
 The path to generate files into, combined with `--op` from the options for a full path.

 
    
### classes[R] [](#attribute-i-classes)
 Classes and modules to be used by this generator, not necessarily displayed.

 
    
### store[R] [](#attribute-i-store)
 The RDoc::Store that is the source of the generated content

 
    
  
  
    
    
      
##  Public Class Methods
      
### new(store, options) [](#method-c-new)
 Initializer method for Rdoc::Generator::Markdown

  
      
    
      
      
  
    
    
      
##  Public Instance Methods
      
### class_dir() [](#method-i-class_dir)
 Directory where generated class HTML files live relative to the output dir.

  
      
### file_dir() [](#method-i-file_dir)
 this alias is required for rdoc to work

  
      
### generate() [](#method-i-generate)
 Generates markdown files and search index file

  
      
    
      
      
  

