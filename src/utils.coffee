shelljs = require 'shelljs'
assert = require 'assert'
{ lstatSync, Stats } = require 'fs'
_ = require 'lodash'
{ execSync } = require 'child_process'
isExe = require 'is-executable'

logger = require './logger'
styler = require './styler'

module.exports = @

shelljs.config.silent = yes

normalizeError = (err) -> err.toString().replace("Error: ", "")

handleError = (error, {
                        exit = yes, # Whether the process may exit on non-allowed error
                        allowedErrors = [] # List of allowed error codes,
                                           # returns null immediately if
                                           # error.code is in this array
                        exitCode = 0,  # if set to 0 defaults to (error.errno ? 1)
                        description = "" # String that will appear before the error text
                        printError = yes # Whether to print the error or not
                      } = {}) ->
    return null if error.code? and error.code in allowedErrors

    errorMsg =
        if description.length
            styler.id(description) + ": " + normalizeError(error)
        else
            normalizeError(error)

    logger.e errorMsg, showStack: no if printError

    exitCode = error.errno ? 1 if exitCode is 0
    process.exit exitCode if exit is yes

    error.toString = -> errorMsg
    error.isError = yes
    error


# Attemps to call a function with a given array of arguments.
# If the call throws a descriptive error is shown and the program exits unless
# otherwise specified
@attempt = (fn, args = [], options) =>
    assert _.isFunction(fn), "utils.attempt argument is not a function" # SANITY-CHECK

    args = [args] unless _.isArray args

    try
        result = fn args...
    catch error
        return handleError error, options

    result

# Same as attempt, but calls the function with name 'fnName' of the module shelljs
@attemptShell = (fnName, args = [], options) ->
    assert _.isFunction(shelljs[fnName]), "Invalid shell function name" # SANITY-CHECK

    args = [args] unless _.isArray args

    result = shelljs[fnName](args...)

    return handleError error, options if (error = shelljs.error())?

    result

# Gets the Stat information of the file in path 'path'.
# If the file was successfully read, returns the Stat object
# If there has been an error and it is not in onError.allowedErrors array,
# returns an object with a property error containing the error
# If an error that was in onError.allowedErrors occurs then null is returned
# Otherwise, the process exits
# Note that EACCESS and ENOENT errors are allowed by default
@getFileInfo = (path, onError = {}) =>
    onError.description ?= "Getting #{path} info"
    onError.allowedErrors ?= ['EACCESS', 'ENOENT']

    result = @attempt lstatSync, path, onError
    if result?.isError?
        { error: result }
    else
        result

# Tells whether 'that' has a modification time older than 'other'
# Assumes arguments are Stat objects unless they're strings
# Prints an error message and exits if either of the arguments is a string
# And an error occured when trying to read the file information via lstatSync
@hasLaterModificationTime = (that, other) =>
    [that, other] = [that, other].map((file) =>
        if _.isString file
            @getFileInfo file, { allowedErrors: [] }
        else
            file
    )

    assert _.every([that, other], (elem) -> elem instanceof Stats),
          "Some argument is not a stat object nor a string"

    thatDate  = new Date(that.mtime)
    otherDate = new Date(other.mtime)
    thatDate.getTime() > otherDate.getTime()

@execSync = (command, options) ->
    options ?= {}
    options.encoding ?= 'utf-8'

    previousStderr = process.stderr.write
    stderr = ""

    process.stderr.write = (s) -> stderr += s.toString()

    try
        result = execSync command, options
    catch error
        process.stderr.write = previousStderr
        throw error

    process.stderr.write = previousStderr
    { stderr, stdout: result }

@isBinaryExecutable = (path) =>
    assert _.isString(path), "Argument must be file path (string)"

    fileToolOutput = @attempt(@execSync, "file #{path}").stdout.toLowerCase()

    fileToolOutput.indexOf('elf') >= 0 and
    fileToolOutput.indexOf('executable') >= 0 and
    isExe.sync path




# Testing Code
###
@attempt(require('fs').unlinkSync, [''], exit: no, description: "Remove file without path")
@attempt(require('fs').unlinkSync, [''], exit: no)
@attempt((->), [], exit: no, description: "Do nothing")
@attemptShell('rm', [''], exit: no, description: "Remove file without path")
@attemptShell('rm', [''], exit: no)
@attemptShell('ls')
console.log @getFileInfo('/dev/null')
console.log @getFileInfo('./dawdawa', { exit: no, printError: no })
console.log @getFileInfo('./dawdawa', { exit: no, printError: no, allowedErrors: [] }).error.toString()
console.log @hasLaterModificationTime('./utils.coffee', './logger.coffee')
console.log @hasLaterModificationTime('./utils.cofee', './logger.coffee')
###