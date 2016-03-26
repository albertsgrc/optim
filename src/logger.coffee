_ = require 'lodash'

{ clearLine, cursorTo } = require 'readline'
{ stripColor } = require 'chalk'

styler = require './styler'

module.exports = @

# Alias
{ stdout, stderr, exit } = process

# Constants
[INFO,WARN,ERROR,VERBOSE] = TAGS = ["INFO", "WARN", "ERROR", "VERBS"]
LEFT_MARGIN = _.maxBy(TAGS, _.size).length + 1
TAG_INDICATOR = ': '
LEFT_PADSTRING_LONG_LINES = _.repeat(" ", LEFT_MARGIN + TAG_INDICATOR.length)
MAX_COLS_PER_LINE = stdout.columns - 1

# Private methods
getNonOcuppyingLength = (str) -> str.length - stripColor(str.replace("\n", "")).length

tag = (txt, style) -> style(_.padEnd(txt, LEFT_MARGIN)) + TAG_INDICATOR

# Assumes there is no endline within the string
fold = (str, leftPad = LEFT_PADSTRING_LONG_LINES) ->
    cols = Math.max 10, MAX_COLS_PER_LINE - leftPad.length
    nonOcuppyingLength = getNonOcuppyingLength(str)
    if str.length - nonOcuppyingLength <= cols # Base case
         str
    else # Recursive case
        cutString = str[...cols + nonOcuppyingLength]
        lastSpace = cutString.lastIndexOf(' ')

        # This if-else is in order to avoid cutting a word in half in case it's possible
        if lastSpace >= 0
            cutString[...lastSpace] + "\n" + leftPad + fold(str[lastSpace+1..])
        else # Quite strange there's no space in 70 character string...
            cutString[...-1] + "-\n" + leftPad + fold(str[cutString.length-1..])

createWriter = (txt, styler, stream = stdout) => (msg, endline = on, margin = off) =>
        msg += "\n" if endline is on
        if margin
            stream.write "\n " + tag(txt, styler) + fold(msg, LEFT_PADSTRING_LONG_LINES + " ") + "\n"
        else
            stream.write tag(txt, styler) + fold(msg)
        @

# Exposed methods
@write = (str, stream = stdout) => stream.write str; @

@endLine = => console.log(""); @

@eraseLine = (stream = stdout) => clearLine(stream); cursorTo(stream, 0); @

@verbose = @v = if global.cli?.verbose? then createWriter VERBOSE, styler.verbose else => @

@info = @i = createWriter INFO, styler.info

@updateInfo = (msg) => @eraseLine(); @info(msg, false); @

@warn = @w = createWriter WARN, styler.warn

@error = @e = do ->
    errorWriter = createWriter ERROR, styler.error, stderr
    (msg, margin = off, end = yes, exitCode = 1) ->
        ret = errorWriter msg, on, margin
        exit exitCode if end is yes
        ret

# Testing Code
###
this
    .i("Thisisastrangelongsentencewithnospacesa#{styler.id 'nditshould'}becutwithahyphenbecause\
        theresnospaceanditcannotbereadcorrectlyiftheterminalistoonarrow.")
    .w("This is a normal sentence which has a lot of columns, so it should be
        cut cause it's too long to be read correctly in the terminal.")
    .warn("This is a warning")
    .error("An error occurred", on, no)
    .info("Be informed")
    .verbose("Don't talk so much")
    .updateInfo("My name is albert")
    .updateInfo("My name is joan")
    .endLine()

stdout.write "Shouldn't appear"; @eraseLine()

@error("This ends with error code 2", off, true, 2)
@info("Should'nt be printed")
###
