path = require 'path'
_ = require 'lodash'
assert = require 'assert'

Program = require './program'
{ attemptShell } = require './utils'

module.exports = class ProgramFamily
    @OPTIMIZED_PROGRAMS_SUFFIX: "-opt*"

    guessOthers = ({ name, execExtension, srcExtension }) =>
        executablesPattern = "#{name}#{@OPTIMIZED_PROGRAMS_SUFFIX}#{execExtension}"
        executables = attemptShell("ls", executablesPattern).sort()
        sourcesPattern = "#{name}#{@OPTIMIZED_PROGRAMS_SUFFIX}#{srcExtension}"
        sources =
            for source in attemptShell("ls", sourcesPattern).sort()
                { dir, name } = path.parse source
                "#{path.join(dir, name)}#{execExtension}"

        for execFile, index in _.union(sources, executables)
            new Program(execFile, isGuessed: yes)

    constructor: (@original, @others) ->
        @original = new Program(@original) if _.isString @original

        assert(@original instanceof Program, "original parameter is not a program nor string")

        @others ?= guessOthers(@original)

        assert(_.isArray(@others), "others must be an array")

        @all = [@original].concat(@others)

    compile: ->
        program.compile() for program in @all


# Testing code

piFamily = new ProgramFamily("/home/albert/Dropbox/UPC/FIB/6eQuatri/PCA/Lab/sessio3/lab3_session/pi/pi.Fgspg")
console.log piFamily
piFamily.compile()
