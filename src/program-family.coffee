path = require 'path'
_ = require 'lodash'
assert = require 'assert'
util = require 'util'
{ OPTIMIZED_PROGRAMS_INDICATOR_PATTERN } = require './constants'
Program = require './program'
{ attemptShell } = require './utils'

module.exports = class ProgramFamily
    guessOthers = ({ name, execExtension, srcExtension }, last) =>
        { dir, base } = path.parse name
        pattern = "^#{base}#{OPTIMIZED_PROGRAMS_INDICATOR_PATTERN}[^.]*\\."
        executablesPattern = new RegExp(pattern + "#{execExtension}$")
        executables = attemptShell("ls", "#{dir}").filter((s) -> s.match(executablesPattern))
        sourcesPattern = new RegExp(pattern + "#{srcExtension}$")
        sources =
            for source in attemptShell("ls",  "#{dir}").filter((s) -> s.match(sourcesPattern))
                { dir2, name } = path.parse source
                dir2 ?= "./"
                maybeDot = if execExtension.length > 0 then "." else ""
                "#{path.join(dir2, name)}#{maybeDot}#{execExtension}"

        found = _.union(sources, executables).sort().map((s) -> path.join(dir, s))

        programs =
            for execFile, index in found
                new Program(execFile, isGuessed: yes)

        if last and programs.length > 0
            programs = [_.maxBy(programs,
                (p) ->
                    stat = if p.hasSrcFile then p.srcFileStat else p.execFileStat
                    new Date(stat.mtime).getTime()
            )]

        programs

    constructor: (@original, @others = [], { last = no, shouldGuess = yes } = {}) ->
        @original = new Program(@original, { isOriginal: yes }) if _.isString @original

        assert(@original instanceof Program, "original parameter is not a program nor string")

        if shouldGuess and @others.length is 0
            @others = guessOthers(@original, last)
        else
            @others[i] = new Program(v) for v, i in @others

        assert(_.isArray(@others), "others must be an array, instead it was: #{util.inspect @others}")

        @all = [@original].concat(@others)

    compile: ->
        program.compile() for program in @all


# Testing code
###
piFamily = new ProgramFamily("/home/albert/Dropbox/UPC/FIB/6eQuatri/PCA/Lab/sessio3/lab3_session/pi/pi.Fgspg")
console.log piFamily
piFamily.compile()
###
