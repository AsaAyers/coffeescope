globals = require 'globals'

class Scope
    constructor: (@_parent) ->

        ScopeVariables = -> this
        if @_parent
            ScopeVariables.prototype = @_parent.getScopeVariables()

        @_variables = new ScopeVariables()
        @_references = []
        @_scopes = []

    pushScope: ->
        scope = new Scope(this)
        @_scopes.push(scope)
        scope

    toJSON: ->
        # Create a new object to break the prototype chain when exporting.
        variables = {}
        for own key, value of @_variables
            variables[key] = value

        tmp = { variables, references: @_references }
        if @_scopes.length
            tmp.scopes = @_scopes.map((s) -> s.toJSON())
        return tmp

    getScopeVariables: -> @_variables

    getParent: -> @_parent

    getChildScopes: -> @_scopes

    define: (name, meta = {}) ->
        if @get(name, true)?
            throw new Error("#{name} is already defined in this scope")

        meta.name = name
        @_variables[name] = meta

    reference: (name, meta = {}) ->
        meta.name = name
        @_references.push(meta)

    get: (name, inCurrentScope = false) ->
        if not inCurrentScope or name in Object.keys(@_variables)
            @_variables[name]

module.exports = class ScopeManager
    constructor: ({@globals, @environments}) ->
        @_currentScope = @_globalScope = new Scope(null)

        for v in ( @globals ? [] )
            @_globalScope.define(v, {
                defined: -1,
                used: true,
            })

        defineAll = (key) =>
            throw new Error "Invalid environment #{key}" unless globals[key]?
            for v of globals[key]
                @_globalScope.define(v, {
                    defined: -1,
                    used: true,
                })

        defineAll 'builtin'
        for env, value of ( @environments ? [] ) when value
            defineAll env

    getGlobalScope: -> @_globalScope

    getCurrentScope: -> @_currentScope

    pushScope: -> @_currentScope = @_currentScope.pushScope()

    popScope: -> @_currentScope = @_currentScope.getParent()

    define: (name, meta) -> @_currentScope.define(name, meta)

    reference: (name, meta) -> @_currentScope.reference(name, meta)

    isDefined: (name, inCurrentScope = false) ->
        @get(name, inCurrentScope)?

    get: (name, inCurrentScope = false) ->
        @_currentScope.get(name, inCurrentScope)

    toJSON: -> @_currentScope.toJSON()
