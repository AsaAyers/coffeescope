# coffeescope

[![Join the chat at https://gitter.im/AsaAyers/coffeescope](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/AsaAyers/coffeescope?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

The goal is to be able to scan a CoffeeScript file and identify every variable created or used in every scope.

Once this is done it will be used by [CoffeeLint](http://www.coffeelint.org/) to add scope rules like `no_undefined_vars`, `no_unused_vars`, `no_variable_shadowing`, and `no_use_before_define`.

# CoffeeScript is terrible

It is my recommendation that you abandon CoffeeScript immediately. [Babel](http://babeljs.io/) with ES6/ES2015 is a much better solution.

CoffeeScript's AST doesn't have all of the information needed to determine how variables are used. The simplest example is implicit returns, they are simply missing from the AST. My workaround was to have the AST compile itself because for some dumbass reason compiling the AST allows it to modify itself and it puts in the explicit return. This introduces new problems; now the AST contains code you didn't write. Your default parameter now exists as part of the parameter AND inside an if statement in the body. This is a major problem when trying to lint what the user wrote.

I expect I am probably going to abandon this project.

## contributing

Right now there are many disabled tests because they are failing. I can be difficult to fix one test without breaking others. My plan is to turn tests on one at a time and fix them.

    # This will re-run the tests after every change
    npm test -- --autotest
