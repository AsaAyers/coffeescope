var CoffeeScript = require('coffee-script');

// TODO: setup a build script to publish compiled versions so we don't have to
// register coffee-script
CoffeeScript.register();

var ScopeManager = require('./src/scope_manager.coffee');
var Scanner = require('./src/scanner.coffee');

module.exports = function(source, options) {
    options = options || {};
    var scopeManager = new ScopeManager({
        globals: options.globals,
        environments: options.environments,
    });
    var scanner = new Scanner(scopeManager);
    var node = CoffeeScript.nodes(source);
    return scanner.scan(node);
}
