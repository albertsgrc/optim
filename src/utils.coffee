shelljs = require 'shelljs'
assert = require 'assert'
{ lstatSync, Stats } = require 'fs'
_ = require 'lodash'

logger = require './logger'
styler = require './styler'

module.exports = @

shelljs.config.silent = yes

normalizeError = (err) -> err.toString().replace("Error: ", "")

printError = (error, description) ->
    if description.length
        logger.e styler.id(description) + ": " + normalizeError(error)
    else
        logger.e normalizeError(error)

# Attemps to call a function with a given array of arguments.
# If the call throws a descriptive error is shown and the program exits unless
# otherwise specified
@attempt = (fn, args = [], { exit = yes, exitCode = 1, description = "" } = {}) =>
    assert _.isFunction(fn), "utils.attempt argument is not a function" # SANITY-CHECK

    args = [args] unless _.isArray args

    try
        result = fn args...
    catch error
        printError error, description
        process.exit exitCode if exit is yes

    result

# Same as attempt, but calls the function with name 'fnName' of the module shelljs
@attemptShell = (fnName, args = [], { exit = yes, exitCode = 1, description = "" } = {}) ->
    assert _.isFunction(shelljs[fnName]), "Invalid shell function name" # SANITY-CHECK

    args = [args] unless _.isArray args

    result = shelljs[fnName](args...)

    if (error = shelljs.error())?
        printError error, description
        process.exit exitCode if exit is yes

    result

# Tells whether 'that' has a modification time older than 'other'
# Assumes arguments are Stat objects unless they're strings
@hasLaterModificationTime = (that, other) =>
    [that, other] = [that, other].map((file) =>
        if _.isString file
            @attempt lstatSync, file, description: "Getting #{file} info"
        else
            file
    )

    assert _.every([that, other], (elem) -> elem instanceof Stats) # SANITY-CHECK

    thatDate  = new Date(that.mtime)
    otherDate = new Date(other.mtime)
    thatDate.getTime() > otherDate.getTime()

# Testing Code
###
@attempt(require('fs').unlinkSync, [''], exit: no, description: "Remove file without path")
@attempt(require('fs').unlinkSync, [''], exit: no)
@attempt((->), [], exit: no, description: "Do nothing")
@attemptShell('rm', [''], exit: no, description: "Remove file without path")
@attemptShell('rm', [''], exit: no)
@attemptShell('ls')
console.log @hasLaterModificationTime('./utils.coffee', './logger.coffee')
console.log @hasLaterModificationTime('./utils.cofee', './logger.coffee')
###
