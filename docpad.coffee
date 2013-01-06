
browserify = require 'browserify'
uglify = require 'uglify-js'

module.exports =
  events:
    render: (opts, next) ->
      if opts.inExtension == 'coffee' and opts.outExtension == 'js'
        {fullPath} = opts.file.attributes
        b = browserify
          filter: (code) ->
            ast = uglify.parse code
            ast.figure_out_scope()
            ast.mangle_names()
            ast.print_to_string()
        b.addEntry fullPath
        opts.content = b.bundle()
        next()
      else
        next()
        
