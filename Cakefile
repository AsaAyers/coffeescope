fs = require('fs')

browserify = require('browserify')

task 'compile:browserify', 'Uses browserify to compile coffeescope', ->

    fs.mkdirSync 'dist' unless fs.existsSync 'dist'

    opts =
        standalone: 'coffeescope'
    b = browserify(opts)
    b.add([ './index.js' ])
    b.transform require('coffeeify')
    b.plugin(require('browserify-derequire'))
    b.bundle().pipe(fs.createWriteStream('dist/coffeescope.js'))

task 'prepublish', "Prepublish hook", ->
    invoke 'compile:browserify'
