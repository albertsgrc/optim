path = require 'path'
_ = require 'lodash'
assert = require 'assert'
util = require 'util'

Program = require './program'
{ attemptShell } = require './utils'

module.exports = class ProgramFamily
    @OPTIMIZED_PROGRAMS_SUFFIX: "-opt"

    guessOthers = ({ name, execExtension, srcExtension }, last) =>
        pattern = "^#{name}#{@OPTIMIZED_PROGRAMS_SUFFIX}((?!\\.).)*"
        executablesPattern = new RegExp(pattern + "#{execExtension.replace(".", "\\.")}$")
        executables = attemptShell("ls").filter((s) -> s.match(executablesPattern))
        sourcesPattern = new RegExp(pattern + "#{srcExtension.replace(".", "\\.")}$")
        sources =
            for source in attemptShell("ls").filter((s) -> s.match(sourcesPattern))
                { dir, name } = path.parse source
                "#{path.join(dir, name)}#{execExtension}"

        found = _.union(sources, executables).sort()


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

    constructor: (@original, @others, { last = no } = {}) ->
        @original = new Program(@original) if _.isString @original

        assert(@original instanceof Program, "original parameter is not a program nor string")

        if not @others? or @others.length is 0
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
