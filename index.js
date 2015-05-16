var ScopeManager = require('./src/scope_manager.coffee');
var Scanner = require('./src/scanner.coffee');

var scan = function(CoffeeScript, source, options) {
    options = options || {};
    var scopeManager = new ScopeManager({
        globals: options.globals,
        environments: options.environments,
    });
    var scanner = new Scanner(scopeManager);
    var node = CoffeeScript.nodes(source);
    return scanner.scan(node);
}

module.exports = {
    scan: scan
};
