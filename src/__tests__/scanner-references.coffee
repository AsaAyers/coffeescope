jest.autoMockOff()

describe 'Scanner references', ->
    [ CoffeeScript, scanner, ScopeManager, Scanner ] = []

    jsonFilter = (key, value) ->
        if key in [ 'scopeChain', 'this', 'arguments', 'locationData' ]
            return undefined
        return value

    scan = (source, { logAst, logScope } = {}) ->
        ast = CoffeeScript.nodes(source)

        scopeManager = new ScopeManager({})
        scanner = new Scanner(scopeManager)
        globalScope = scanner.scan(ast)

        if logAst
            console.log(ast.toString())
        if logScope
            console.log(JSON.stringify(globalScope.scopes[0], jsonFilter, 2))
        # Return the root scope
        return globalScope.scopes[0]

    beforeEach ->
        CoffeeScript = require('coffee-script')
        ScopeManager = require('../scope_manager.coffee')
        Scanner = require('../scanner.coffee')

    beforeEach ->
        referenceTo = (target) ->
            return (ref) -> ref.name is target

        this.addMatchers({
            toReference: (refName, expected = 1) ->
                total = this.actual.references.filter(referenceTo(refName))
                this.message = ->
                    return [
                        "Expected scope to reference #{refName} x #{expected}
                        found: #{total.length}"
                        "Expected scope not to reference #{refName} x
                        #{expected} found: #{total.length}"
                    ]

                return total.length is expected
        })

    it 'picks up assignments', ->
        root = scan('''
        foo = 'somestring'
        foo = bar
        foo = bar.baz
        foo = baz.whatever
        ''')

        expect(root.references.length).toBe(3)
        expect(root).toReference('bar', 2)
        expect(root).toReference('baz', 1)

    it 'Picks up function calls and parameters', ->
        root = scan('''
        someFunction(paramA)
        ''')

        expect(root.references.length).toBe(2)
        expect(root).toReference('someFunction')
        expect(root).toReference('paramA')

    it 'picks up class extensions', ->
        root = scan('''
        class Foo extends Bar
        ''')

        expect(root.references.length).toBe(1)
        expect(root).toReference('Bar')

    it 'picks up object litterals', ->
        root = scan('''
        baz = undefined
        foo = {
            bar: BAR,
            baz
        }
        ''')

        expect(root.references.length).toBe(2)
        expect(root).toReference('BAR')
        expect(root).toReference('baz')

    it 'picks up property assignments and array style assignments', ->
        root = scan('''
        foo.prop = true
        bar[0] = true
        baz[qux] = true
        ''')

        expect(root.references.length).toBe(4)
        expect(root).toReference('foo')
        expect(root).toReference('bar')
        expect(root).toReference('baz')
        expect(root).toReference('qux')

    it 'recognizes param properties', ->
        root = scan('''
        someFunction(foo.something)
        ''')

        expect(root).toReference('someFunction')
        expect(root).toReference('foo')

    it 'picks up destructuring from a reference', ->
        root = scan('''
        { a } = foo
        ''')

        expect(root).not.toReference('a')
        expect(root).toReference('foo')

    it 'scans for loops', ->
        root = scan('''
        for {name, value} in node.params
            undefined

        for x in [1, 2, 3]
            undefined
        ''')

        expect(root.references.length).toBe(1)
        expect(root).toReference('node')

    it 'scans ifs', ->
        root = scan('''
        if name is 'Assign' and (foo is 'foo' or bar is 'bar')
            undefined

        isNew = true
        if isNew
            undefined
        ''')

        expect(root.references.length).toBe(4)
        expect(root).toReference('name')
        expect(root).toReference('foo')
        expect(root).toReference('bar')
        expect(root).toReference('isNew')

    it 'scans returns', ->
        root = scan('''
        class Scanner
            getNodeName: (node) ->
                return node.constructor.name
            otherMethod: ->
                # implies undefined
                return
        ''')

        scannerScope = root.scopes[0]
        getScope = scannerScope.scopes[0]

        expect(getScope).toReference('node')

    it 'code-sample-2', ->
        root = scan('''
        class Scanner
            destructureArray: (node) ->
                for obj in node.unwrapAll().objects
                    undefined
                for obj in something
                    undefined
        ''')

        scannerScope = root.scopes[0]
        destructureScope = scannerScope.scopes[0]

        expect(destructureScope).toReference('node')
        expect(destructureScope).toReference('something')

    it 'Considers exported classes to be referenced', ->
        root = scan('''
        module.exports = class Scanner
        ''')

        expect(root).toReference('Scanner')

    it 'code-sample-3', ->
        root = scan('''
        referenceTo = (target) ->
            return (ref) -> ref.name is target
        ''')

        refToScope = root.scopes[0]
        anonScope = refToScope.scopes[0]
        expect(anonScope).toReference('ref')
        expect(anonScope).toReference('target')

    it 'scans guards in for loops', ->
        root = scan('''
        for s in [] when hasBeenReferenced(variable, s)
            return true
        ''')

        expect(root).toReference('hasBeenReferenced')
        expect(root).toReference('variable')
        expect(root).toReference('s')

    it 'code-sample-4', ->
        root = scan('''
        toHaveVariable = (expected) ->
            return this.actual.variables[expected]?
        ''')

        expect(root.scopes[0]).toReference('expected')

    it 'scans string interpolations', ->
        root = scan('''
        foo = 'something'
        return "something #{foo}"
        ''')

        expect(root).toReference('foo')

    it 'references returned classes', ->
        root = scan('''
        ->
            return class Foo
        ->
            class Bar
        ''')

        expect(root.scopes[0]).toReference('Foo')
        expect(root.scopes[1]).toReference('Bar')

    it 'scans variables used to construct arrays', ->
        root = scan('''
        (foo) ->
            ['something', foo]
        ''')

        expect(root.scopes[0]).toReference('foo')

    it 'scans switch statements', ->
        root = scan('''
        foo = undefined
        switch foo
            when 'foo' then undefined
        ''')

        expect(root).toReference('foo')

    it 'scans throws', ->
        root = scan('''
        try
            throw new Error('foo')
        catch error
            throw error
        ''')

        expect(root).toReference('error')

    it 'code-sample-5', ->

        root = scan('''
        index = 0
        processNext = ->
            processor(input[index++])
        ''')

        expect(root.scopes[0]).toReference('index')

    it 'code-sample-6', ->
        root = scan('''
        fieldNames = Object.keys(updatedFields)
        body = _.pick(sData, fieldNames...)
        ''')

        expect(root).toReference('fieldNames')

    it 'code-sample-7', ->
        root = scan('''
        foo = ->
            url = CONST.SOMETHING
            params = [ ]
            url += params.join('&')
        ''')

        expect(root.scopes[0]).toReference('url')

    it 'code-sample-8', ->
        root = scan('''
        Something = require 'something'
        class Foo
            constructor: (@_storage=new Something.Storage()) ->
        ''')

        fooScope = root.scopes[0]
        constructorScope = fooScope.scopes[0]
        expect(constructorScope).toReference('Something')

    it 'code-sample-9', ->
        root = scan('''
        p = p.fail (xhr) =>
            throw err or generateError()
        ''')

        failScope = root.scopes[0]
        expect(failScope).toReference('err')

    it 'code-sample-10', ->
        root = scan('''
        CONST = require '../../const'
        if context
            CONST.FOO
        else
            CONST.BAR
        feature =
            if context
                CONST.FOO
            else
                CONST.BAR
        ''')

        expect(root).toReference('CONST')
        expect(root).toReference('context')

    it 'code-sample-11', ->
        root = scan('''
        from = 0
        to = words.length
        selectedWords = ( w.word for w in words[from..to] )
        ''')

        expect(root).toReference('from')
        expect(root).toReference('to')
        expect(root).toReference('w')

    it 'code-sample-12', ->
        root = scan('''
        foo = -> []
        for s in foo()
            undefined
        ''')

        expect(root).toReference('foo')

    it 'code-sample-13', ->
        root = scan('''
        prefix = "some prefix"
        throw new Error "#{prefix}: Invalid something"
        ''')

        expect(root).toReference('prefix')

    it 'code-sample-14', ->
        root = scan('''
        { first_column, last_column } = token[2]
        actual_token = line[first_column..last_column]
        ''')

        expect(root).toReference('first_column')
        expect(root).toReference('last_column')
