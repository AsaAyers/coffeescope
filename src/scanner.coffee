
leafNode = {}
hasBeenScanned = '_scanner_' + Math.random()

module.exports = class Scanner

    constructor: (@scopeManager) ->

    scan: (rootNode) ->
        # The AST will actually transform itself in the process of compiling.
        # This converts the implicit returns into explicit returns and seems to
        # do something with comprehensions to make them scannable
        rootNode.compile({ bare: true })

        @debugStack = []
        @wrapInScope =>
            @scanChildren(rootNode)

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

        if not node.isAssignable() and not node.isComplex()
            undefined

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
        return leafNode

    scanNode: (node) =>
        if not node? then throw new Error('Missing node')

        @lastNode = @getNodeName(node)
        if node[hasBeenScanned]
            console.log(node[hasBeenScanned])
            console.log('now\n===')
            console.log(@debugStack)
            console.log(node)
            throw new Error("Scanned the same #{@lastNode} more than once")
        node[hasBeenScanned] = @debugStack.slice()

        @debugStack.push(@lastNode)

        x = switch (@getNodeName(node))
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
            when 'Range' then @scanRange(node)
            when 'Parens' then @scanParens(node)
            # when 'Splat' then @checkExists node.name.base
            when 'Switch' then @scanSwitch node
            when 'Throw' then @scanThrow node
            when 'Try' then @scanTry node

        if x isnt leafNode
            @scanChildren(node)

        @debugStack.pop()
        undefined

    scanChildren: (node) ->
        node.eachChild (childNode) =>
            @scanNode(childNode) if childNode

    scanIf: (node) ->
        if @getNodeName(node.condition) is 'Value'
            @reference(node.condition)

    scanIndex: (node) ->
        @reference(node.index)

    scanObj: (node) ->
        for p in node.properties
            if p.isAssignable()
                @reference(p)

    scanArr: (node) ->
        for obj in node.objects
            @reference(obj)

    scanAssign: (node) ->
        { variable, value }  = node

        if variable.isObject?()
            @destructureObject(variable)
        else if variable.isArray?()
            @destructureArray variable
        else
            # The isAssignable check will prevent processing strings:
            # { "key": "value" }
            # The above is an assignement, but `key` is not assignable.
            if variable.isAssignable() and variable.properties?.length is 0 and
                    # context prevents picking up class properties
                    node.context isnt 'object'

                @define(variable)

            if variable.isAssignable() and variable.properties?.length > 0
                @reference(variable)

                for { index } in variable.properties when index?
                    @reference(index)

        @reference(value)

    scanCall: (node) ->
        { args, variable } = node
        for arg in args
            @reference(arg.unwrapAll())

        @reference(variable)

    scanClass: (node) ->
        # This may be an anonymous class
        if node.variable?
            @define(node.variable)

        if node.parent
            @reference(node.parent)

        console.log('scanClass')
        return @wrapInScope =>
            @scanChildren(node)

    scanCode: (node) ->
        return @wrapInScope =>
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
                    @scanNode(value)

            @paramIndex = undefined
            @scanNode(node.body)

    scanExistence: (node) ->
        @reference(node.expression)

    scanFor: (node) ->
        { source, name, index, body } = node

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

        @reference(source)

        @scanNode(source)
        @scanNode(body)

        return leafNode

    scanOp: (node) ->
        { first, second } = node

        @reference first

        if second?
            @reference second

    scanReturn: (node) ->
        if node.expression
            @reference(node.expression)

    scanRange: (node) ->
        @reference(node.from)
        @reference(node.to)

    scanParens: (node) ->
        for exp in node.body.expressions
            @reference(exp)

    scanSwitch: (node) ->
        @reference(node.subject)

    scanThrow: (node) ->
        @reference(node.expression)

    scanTry: (node) ->
        { errorVariable } = node
        if errorVariable
            if errorVariable.isComplex()
                @scanDestructure(errorVariable)
            else
                @define(errorVariable)

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
