fs = require('fs')

browserify = require('browserify')

task 'compile:browserify', 'Uses browserify to compile coffeescope', ->

    fs.mkdirSync 'dist' unless fs.existsSync 'dist'

    opts =
        fullPaths: true
    b = browserify('./index.js', opts)
    # b.require [ './index.js' ]
    b.transform require('coffeeify')
    b.plugin(require('browserify-derequire'))
    b.bundle().pipe(fs.createWriteStream('dist/coffeescope.js'))

task 'prepublish', "Prepublish hook", ->
    invoke 'compile:browserify'
