

module.exports = class Scanner

    constructor: (@scopeManager) ->

    scan: (rootNode) ->
        @scopeManager.pushScope()
        rootNode.eachChild @_scanNode
        @scopeManager.popScope()

        # If this ever happens it indicates something is wrong in the code.
        # Probably not something a user could ever trigger.
        if @scopeManager.getCurrentScope() != @scopeManager.getGlobalScope()
            throw new Error "Error walking AST to collect scopes"

        # I'm not totallly sure if this is valid, so I want to find it if it
        # ever happens.
        if @scopeManager.getCurrentScope().getChildScopes().length != 1
            throw new Error "Found multiple root scopes"

        return @scopeManager.toJSON()

    # CoffeeLint's getNodeName() is incomplete, so until I figure out how to
    # make it detect all node names, I'll just use this which doesn't work with
    # minified code
    getNodeName: (node) ->
        return node.constructor.name

    define: (node, options = {}) ->
        shadow = options.shadow ? false
        paramIndex = @paramIndex
        unwrapped = node.unwrapAll()

        if not @scopeManager.isDefined(unwrapped.value, shadow)
            @scopeManager.define(unwrapped.value, {
                locationData: unwrapped.locationData
                paramIndex
            })

    reference: (node) ->
        unwrapped = node.unwrapAll()


        if @getNodeName(node) is 'Class' and node.variable
            return @reference(node.variable)

        # isAssignable seems to be an indication that this is some sort of
        # variable. It's simple enough to just add this guard here so that
        # when object/array litterals are passed it it just doesn't do anything.
        if not node.isAssignable() and not node.isComplex()
            undefined
        else if node.isComplex()
            if unwrapped.variable?.base?.value
                @scopeManager.reference(unwrapped.variable.base.value, {
                    locationData: unwrapped.locationData
                })
            else if unwrapped.base?.value
                @scopeManager.reference(unwrapped.base.value, {
                    locationData: unwrapped.locationData
                })
            else if unwrapped.base?.variable
                @reference(unwrapped.base.variable)
        else
            if unwrapped.value
                @scopeManager.reference(unwrapped.value, {
                    locationData: unwrapped.locationData
                })

    wrapInScope: (callback) ->
        @scopeManager.pushScope()
        callback()
        @scopeManager.popScope()

    _scanNode: (node) =>
        switch (@getNodeName(node))
            when 'Arr' then @scanArr node
            when 'Assign' then @scanAssign node
            when 'Call' then @scanCall node
            when 'Class' then @scanClass node
            when 'Code' then @scanCode node
            # when 'Comment' then @lintComment node
            when 'Existence' then @scanExistence node
            when 'For' then @scanFor node
            # when 'In' then @lintIn node
            when 'If' then @scanIf(node)
            when 'Index' then @scanIndex(node)
            when 'Obj' then @scanObj(node)
            when 'Op' then @scanOp node
            when 'Return' then @scanReturn(node)
            when 'Parens' then @scanParens(node)
            # when 'Splat' then @checkExists node.name.base
            when 'Switch' then @scanSwitch node
            when 'Throw' then @scanThrow node
            when 'Try' then @scanTry node
            when 'While' then @scanWhile(node)
            else
                @_scanChildren(node)

        undefined

    _scanChildren: (node) ->
        node.eachChild (childNode) =>
            @_scanNode(childNode) if childNode
            true
        undefined


    scanIf: (node) ->
        if @getNodeName(node.condition) is 'Value'
            @reference(node.condition)

        @_scanChildren(node)

    scanIndex: (node) ->
        @reference(node.index)
        @_scanNode(node.index)

    scanObj: (node) ->
        for p in node.properties
            if p.isAssignable()
                @reference(p)
            else
                @_scanNode(p)

    scanArr: (node) ->
        for obj in node.objects
            @reference(obj)
            @_scanNode(obj)

    scanAssign: (node) ->
        { variable, value }  = node

        if variable.isObject()
            @destructureObject(variable)
        else if variable.isArray()
            @destructureArray variable
        else
            # The isAssignable check will prevent processing strings:
            # { "key": "value" }
            # The above is an assignement, but `key` is not assignable.
            if variable.isAssignable() and variable.properties.length is 0 and
                    # context prevents picking up class properties
                    node.context isnt 'object'

                @define(variable)

            if variable.isAssignable() and variable.properties.length > 0
                @reference(variable)

                for { index } in variable.properties when index?
                    @reference(index)

        @reference(value)

        return @_scanNode(value)

    scanCall: (node) ->
        { args, variable } = node
        for arg in args
            @reference(arg.unwrapAll())
            @_scanNode(arg)

        @reference(variable)
        @_scanNode(variable)

    scanClass: (node) ->
        # This may be an anonymous class
        if node.variable?
            @define(node.variable)

        if node.parent
            @reference(node.parent)

        @wrapInScope =>
            # Class
            #   Value "Foo"
            #   Block # node.body
            #     Value
            #       Obj
            #         Assign
            #         Assign

            node.body.eachChild (childNode) =>
                if childNode
                    name = @getNodeName(childNode)
                    if name is 'Assign'
                        @scanAssign childNode
                    else if name is 'Value'
                        # unwrapAll() here seems to unwrap Obj and give me the
                        # Assigns that are needed
                        for prop in childNode.unwrapAll().properties
                            @_scanNode(prop)

    scanCode: (node) ->
        @wrapInScope =>
            for { name, value }, paramIndex in node.params
                @paramIndex = paramIndex
                # Complex values seem to invovle property access
                # this.whatever = ... # complex
                # whatever = ... # not complex
                if name.isAssignable() and not name.isComplex()
                    @define(name, {
                        shadow: true
                    })
                else if name.isComplex()
                    if name.base?.value isnt 'this'
                        @scanDestructure(name)

                if value?
                    @_scanNode(value)

            @paramIndex = undefined

            # I don't like that calling node.body.makeReturn() changes the AST
            # Based on the implementation of Block::makeReturn() I don't think
            # this will modify the AST.
            expressions = node.body.expressions
            returnIndex = expressions.length
            while returnIndex--
                expr = expressions[returnIndex]
                if @getNodeName(expr) isnt 'Comment'
                    break

            for exp, index in expressions
                if index is returnIndex
                    exp = exp.makeReturn()
                @_scanNode(exp)

    scanExistence: (node) ->
        @reference(node.expression)
        @_scanNode(node.expression)

    scanFor: (node) ->
        { source, name, index } = node

        @reference(source)

        if name?
            if name.isComplex()
                @scanDestructure(name)
            else
                @define(name)

        if index?
            if index.isComplex()
                @scanDestructure(index)
            else
                @define(index)

        @_scanNode(node.body)
        if node.guard
            @_scanNode(node.guard)

    scanOp: (node) ->
        { first, second } = node
        @reference first

        if second?
            @reference second
        @_scanChildren(node)

    scanReturn: (node) ->
        if node.expression
            @reference(node.expression)
            @_scanNode(node.expression)

    scanParens: (node) ->
        for exp in node.body.expressions
            @reference(exp)
            @_scanNode(exp)

    scanSwitch: (node) ->
        @reference(node.subject)
        @_scanChildren(node)

    scanThrow: (node) ->
        @reference(node.expression)
        @_scanChildren(node.expression)

    scanTry: (node) ->
        { errorVariable } = node
        if errorVariable
            if errorVariable.isComplex()
                @scanDestructure(errorVariable)
            else
                @define(errorVariable)

        @_scanChildren(node)

    scanWhile: (node) ->
        @_scanNode(node.body)

    destructureObject: (node) ->
        for prop in node.unwrapAll().properties
            if prop.isAssignable()
                @define(prop)
            else if prop.value.isAssignable()
                @define(prop.value)
            else
                @scanDestructure(prop.value)

    destructureArray: (node) ->
        for obj in node.unwrapAll().objects
            # Expansions ( [ first, ..., last ]) are not assignable or complex
            # so they will get skipped.
            if obj.isAssignable()
                @define(obj)
            if obj.isComplex()
                @scanDestructure(obj)

    scanDestructure: (node) ->
        if node.unwrapAll().properties?
            @destructureObject(node)
        else
            @destructureArray(node)
