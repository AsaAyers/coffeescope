
wrapInScope = (scopeManager, callback) ->
    try
        scopeManager.pushScope()
        callback()
    finally
        scopeManager.popScope()

describe 'ScopeManager', ->

    it 'Starts at the default scope', ->
        ScopeManager = require('../scope_manager.coffee')
        scopeManager = new ScopeManager({})

        expect(scopeManager.getCurrentScope())
            .toBe(scopeManager.getGlobalScope())


    it 'has the builtins defined', ->
        ScopeManager = require('../scope_manager.coffee')
        scopeManager = new ScopeManager({})

        expect(scopeManager.isDefined('jest')).toBe(false)
        expect(scopeManager.isDefined('Error')).toBe(true)

    it 'traverses scopes', ->
        ScopeManager = require('../scope_manager.coffee')
        scopeManager = new ScopeManager({})

        # Leave global scope
        scopeManager.pushScope()

        scopeManager.define('top', {})
        scopeManager.pushScope()
        scopeManager.define('second', {})

        expect(scopeManager.isDefined('top')).toBe(true)
        expect(scopeManager.isDefined('second')).toBe(true)

        scopeManager.popScope()
        expect(scopeManager.isDefined('top')).toBe(true)
        expect(scopeManager.isDefined('second')).toBe(false)

        scopeManager.pushScope()
        scopeManager.define('third', {})
        expect(scopeManager.isDefined('top')).toBe(true)
        expect(scopeManager.isDefined('second')).toBe(false)
        expect(scopeManager.isDefined('third')).toBe(true)

    it 'only allows defining a variable once per scope', ->
        ScopeManager = require('../scope_manager.coffee')
        scopeManager = new ScopeManager({})

        wrapInScope scopeManager, -> # root
            scopeManager.define('root', {})

            expect(->
                scopeManager.define('root', {})
            ).toThrow()

    describe 'get()', ->



    describe 'toJSON()', ->
        it 'returns plain objects without prototype chaining', ->
            ScopeManager = require('../scope_manager.coffee')
            scopeManager = new ScopeManager({})

            wrapInScope scopeManager, -> # root
                scopeManager.define('root', {})
                wrapInScope scopeManager, -> # fooScope
                    scopeManager.define('foo', {})

            global = scopeManager.toJSON()
            root = global.scopes[0]
            fooScope = root.scopes[0]

            # Verify these are the correct scopes
            expect(fooScope.variables.foo).not.toBeUndefined()
            expect(root.variables.root).not.toBeUndefined()

            # This shouldn't be in fooScope scope, it's in the root scope
            expect(fooScope.variables.root).toBeUndefined()
