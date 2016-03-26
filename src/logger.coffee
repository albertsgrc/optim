_ = require 'lodash'
assert = require 'assert'
{ clearLine, cursorTo } = require 'readline'

styler = require './styler'
{ verbose } = require './cli'

module.exports = @

# Alias
{ stdout, stderr, exit } = process

# Constants
[INFO,WARN,ERROR,VERBOSE] = TAGS = ["INFO", "WARN", "ERROR", "VERBS"]
LEFT_MARGIN = _.maxBy(TAGS, _.size).length + 1
TAG_INDICATOR = ': '
LEFT_PADSTRING_LONG_LINES = _.repeat(" ", LEFT_MARGIN + TAG_INDICATOR.length)
MAX_COLS_PER_LINE = Math.max 10, stdout.columns - LEFT_PADSTRING_LONG_LINES.length - 1

# Private methods
tag = (txt, style) -> style(_.padEnd(txt, LEFT_MARGIN)) + TAG_INDICATOR

fold = (str, cols = MAX_COLS_PER_LINE) ->
    assert cols > 0 # SANITY-CHECK
    if str.length <= cols # Base case
         str
    else # Recursive case
        cutString = str[...cols]
        lastSpace = cutString.lastIndexOf(' ')

        # This if-else is in order to avoid cutting a word in half in case it's possible
        if lastSpace >= 0
            cutString[...lastSpace] + "\n" +
            LEFT_PADSTRING_LONG_LINES +
            fold(str[lastSpace+1..])
        else # Quite strange there's no space in 70 character string...
            cutString[...-1] + "-\n" + LEFT_PADSTRING_LONG_LINES + fold(str[cols-1..])

createWriter = (txt, styler, stream = stdout) => (msg, endline = on) =>
        msg += "\n" if endline is on
        stream.write tag(txt, styler) + fold(msg)
        @

# Exposed methods
@endLine = => console.log(""); @

@eraseLine = (stream = stdout) => clearLine(stream); cursorTo(stream, 0); @

@verbose = @v = if verbose? then createWriter VERBOSE, styler.verbose else => @

@info = @i = createWriter INFO, styler.info

@updateInfo = (msg) => @eraseLine(); @info(msg, false); @

@warn = @w = createWriter WARN, styler.warn

@error = @e = do ->
    errorWriter = createWriter ERROR, styler.error, stderr
    (msg, end = yes, exitCode = 1) ->
        ret = errorWriter msg
        exit exitCode if end is yes
        ret


# Testing Code
###
this
    .i("Thisisastrangelongsentencewithnospacesanditshouldbecutwithahyphenbecause\
        theresnospaceanditcannotbereadcorrectlyiftheterminalistoonarrow.")
    .w("This is a normal sentence which has a lot of columns, so it should be
        cut cause it's too long to be read correctly in the terminal.")
    .warn("This is a warning")
    .error("An error occurred", false)
    .info("Be informed")
    .verbose("Don't talk so much")
    .updateInfo("My name is albert")
    .updateInfo("My name is joan")
    .endLine()

stdout.write "Shouldn't appear"; @eraseLine()

@error("This ends with error code 2", true, 2)
@info("Should'nt be printed")
###
