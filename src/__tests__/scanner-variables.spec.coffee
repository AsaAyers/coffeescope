
describe 'Scanner variables', ->
    [ CoffeeScript, scanner, ScopeManager, Scanner ] = []

    scan = (source, { logAst, logScope } = {}) ->
        ast = CoffeeScript.nodes(source)
        if logAst
            console.log(ast.toString())

        scopeManager = new ScopeManager({})
        scanner = new Scanner(scopeManager)
        globalScope = scanner.scan(ast)

        if logScope
            console.log(JSON.stringify(globalScope.scopes[0], undefined, 2))
        # Return the root scope
        return globalScope.scopes[0]

    beforeEach ->
        CoffeeScript = require('coffee-script')
        ScopeManager = require('../scope_manager.coffee')
        Scanner = require('../scanner.coffee')

    beforeEach ->
        this.addMatchers({
            toHaveVariables: ->
                this.message = ->
                    return [
                        "Expected scope to have variables"
                        "Expected scope not to have variables"
                    ]
                return Object.keys(this.actual.variables).length > 0

            toHaveVariable: (expected) ->
                this.message = ->
                    return [
                        "Expected scope to have variable #{expected}"
                        "Expected scope not to have variable #{expected}"
                    ]
                return this.actual.variables[expected]?
            toHaveScopes: (expected = 1) ->
                this.message = ->
                    return [
                        "Expected scope to have #{expected} child scopes"
                        "Expected scope not to have #{expected} child scopes"
                    ]

                return this.actual.scopes?.length is expected
        })


    it 'picks up assignments', ->
        root = scan("foo = 'foo'")

        expect(root).toHaveVariable('foo')

    it 'picks up destructuring object assignments', ->
        root = scan('''
        { foo, bar: BAR, one: { two: BAZ} } = {}
        ''')

        expect(root).toHaveVariable('foo')
        expect(root).toHaveVariable('BAR')
        expect(root).toHaveVariable('BAZ')

    it 'picks up destructuring array assignments', ->
        root = scan('''
        [ foo, ..., [ bar, [ baz ] ] ] = []
        ''')

        expect(root).toHaveVariable('foo')
        expect(root).toHaveVariable('bar')
        expect(root).toHaveVariable('baz')

    it 'picks up function parameters', ->
        root = scan('''
        fn = (a, b = 2, @c) ->
            d = undefined
        ''')

        expect(root).toHaveVariable('fn')

        expect(root).toHaveScopes()
        fnScope = root.scopes[0]
        expect(fnScope).toHaveVariable('a')
        expect(fnScope).toHaveVariable('b')
        expect(fnScope).not.toHaveVariable('c')
        expect(fnScope).toHaveVariable('d')

    it 'scans try/catch/finally blocks', ->
        root = scan('''
        try
            tryVariable = undefined
        catch error
            catchVariable = undefined
        finally
            finallyVariable = undefined
        ''')

        expect(root).toHaveVariable('tryVariable')
        expect(root).toHaveVariable('catchVariable')
        expect(root).toHaveVariable('finallyVariable')

    it 'picks up catch variables', ->
        root = scan('''
        try
            doSomething()
        catch error
            console.log(error)

        try
            doSomething()
        catch { message }
            console.log(error)
        ''')

        expect(root).toHaveVariable('error')
        expect(root).toHaveVariable('message')

    it 'picks up classes', ->
        root = scan('''
        class Foo
            constructor: (@options) ->

            data:
                key1: 'value'

            internalVariable = undefined

            x: (foo) -> undefined
            @y: (bar) -> undefined

        ''')

        expect(root).toHaveVariable('Foo')

        expect(root).toHaveScopes()
        fooScope = root.scopes[0]

        expect(fooScope).toHaveVariable('internalVariable')
        expect(fooScope).not.toHaveVariable('data')

        expect(fooScope).toHaveScopes(3)
        constructorScope = fooScope.scopes[0]
        xScope = fooScope.scopes[1]
        yScope = fooScope.scopes[2]

        expect(constructorScope).not.toHaveVariables()
        expect(xScope).toHaveVariable('foo')
        expect(yScope).toHaveVariable('bar')

    # Found this scanning my own code. No idea what to call it
    it 'scans through objects', ->
        root = scan('''
        module.exports = class
            rule:
                environments: do ->
                    cfg = {}
        ''')

        expect(root).toHaveScopes()
        clsScope = root.scopes[0]
        expect(clsScope).toHaveScopes()

        environmentScope = clsScope.scopes[0]
        expect(environmentScope).toHaveVariable('cfg')


    it 'scans through complex assignments', ->
        root = scan('''
        module.exports = class Foo
            internalVariable = undefined
        ''')

        expect(root).toHaveVariable('Foo')
        expect(root).toHaveScopes()
        fooScope = root.scopes[0]

        expect(fooScope).toHaveVariable('internalVariable')

    it 'scans function calls', ->
        root = scan('''
        describe 'Scanner', ->
            inception = true

        jasmine.describe 'Scanner', ->
            inception2 = true
        ''')

        expect(root).toHaveScopes(2)
        expect(root.scopes[0]).toHaveVariable('inception')
        expect(root.scopes[1]).toHaveVariable('inception2')

    it 'scans for loops', ->
        root = scan('''
        for valueA in []
            bodyA = undefined
        for valueB, indexB in []
            bodyB = undefined

        for keyC, valueC of {}
            bodyC = undefined
        for own keyD, valueD of {}
            bodyD = undefined

        for keyE of {}
            bodyE = undefined
        for own keyF of {}
            bodyF = undefined

        for { objDestructure } in []
            bodyObj = undefined
        for [ arrDestructure ] in []
            bodyArr = undefined
        ''')

        expect(root).not.toHaveScopes()
        expect(root).toHaveVariable('valueA')
        expect(root).toHaveVariable('bodyA')

        expect(root).toHaveVariable('valueB')
        expect(root).toHaveVariable('indexB')
        expect(root).toHaveVariable('bodyB')

        expect(root).toHaveVariable('keyC')
        expect(root).toHaveVariable('valueC')
        expect(root).toHaveVariable('bodyC')

        expect(root).toHaveVariable('keyD')
        expect(root).toHaveVariable('valueD')
        expect(root).toHaveVariable('bodyD')

        expect(root).toHaveVariable('keyE')
        expect(root).toHaveVariable('bodyE')
        expect(root).toHaveVariable('keyF')
        expect(root).toHaveVariable('bodyF')

        expect(root).toHaveVariable('objDestructure')
        expect(root).toHaveVariable('bodyObj')
        expect(root).toHaveVariable('arrDestructure')
        expect(root).toHaveVariable('bodyArr')

    it 'only picks up the first definition of a variable', ->
        root = scan('''
        foo = undefined
        foo = undefined
        ''')

        expect(root).toHaveVariable('foo')
        expect(root.variables.foo.locationData.first_line).toBe(0)

    it 'scans If/Else', ->
        root = scan('''
        if true
            foo = undefined
        else
            bar = undefined

        unless baz
            baz = undefined

        qux = if true then 'qux' else 'wat'
        ''')

        expect(root).toHaveVariable('foo')
        expect(root).toHaveVariable('bar')
        expect(root).toHaveVariable('baz')
        expect(root).toHaveVariable('qux')

    it 'scans IIFEs (do ->)', ->
        root = scan('''
        do ->
            foo = undefined
        ''')

        expect(root).toHaveScopes()
        expect(root.scopes[0]).toHaveVariable('foo')

    it 'scans while loops', ->
        root = scan('''
        while true
            foo = undefined
        ''')

        expect(root).not.toHaveScopes()
        expect(root).toHaveVariable('foo')

    it 'parameters shadow variables from upper scopes', ->
        root = scan('''
        foo = undefined
        test = (foo) ->
        ''')

        expect(root).toHaveVariable('foo')
        expect(root).toHaveScopes()

        testScope = root.scopes[0]
        expect(testScope).toHaveVariable('foo')


    it "Assignments don't shadow variables from upper scopes", ->
        root = scan('''
        foo = undefined
        setFoo = (f) ->
            foo = f
        ''')

        expect(root).toHaveVariable('foo')
        expect(root).toHaveScopes()

        setFoo = root.scopes[0]
        expect(setFoo).not.toHaveVariable('foo')

    it 'marks parameters with paramIndex', ->
        root = scan('''
        (foo, { bar, baz }, [ qux ], @options ) ->
        ''')

        fnScope = root.scopes[0]

        expect(fnScope).toHaveVariable('foo')
        expect(fnScope).toHaveVariable('bar')
        expect(fnScope).toHaveVariable('baz')
        expect(fnScope).toHaveVariable('qux')
        expect(fnScope).not.toHaveVariable('options')

        expect(fnScope.variables.foo.paramIndex).toBe(0)
        expect(fnScope.variables.bar.paramIndex).toBe(1)
        expect(fnScope.variables.baz.paramIndex).toBe(1)
        expect(fnScope.variables.qux.paramIndex).toBe(2)
