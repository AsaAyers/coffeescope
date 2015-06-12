# coffeescope

The goal is to be able to scan a CoffeeScript file and identify every variable created or used in every scope.

Once this is done it will be used by [CoffeeLint](http://www.coffeelint.org/) to add scope rules like `no_undefined_vars`, `no_unused_vars`, `no_variable_shadowing`, and `no_use_before_define`.

## contributing

Right now there are many disabled tests because they are failing. I can be difficult to fix one test without breaking others. My plan is to turn tests on one at a time and fix them.

    # This will re-run the tests after every change
    npm test -- --autotest
