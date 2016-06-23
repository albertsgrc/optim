path = require 'path'
_ = require 'lodash'
assert = require 'assert'
util = require 'util'
{ OPTIMIZED_PROGRAMS_INDICATOR_PATTERN } = require './constants'
Program = require './program'
{ attemptShell } = require './utils'

module.exports = class ProgramFamily
    guessOthers = ({ name, execExtension, srcExtension }) =>
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

        _.union(sources, executables).sort().map((s) -> new Program path.join(dir, s), { isGuessed: yes })

    constructor: (@original, @others = [], { shouldGuess = yes, indexFilter } = {}) ->
        assert(_.isArray(@others), "others must be an array, instead it was: #{util.inspect @others}")
        assert(_.isString(@original), "original parameter is not a string")

        @original = new Program(@original, { isOriginal: yes })

        guessed =
            if shouldGuess and @others.length is 0
                guessOthers @original, { isOriginal: yes }
            else
                []

        @all = [@original]
                .concat(new Program p for p in @others)
                .concat(guessed)

        allSortedByMt = _.sortBy(@all,
                    (p) ->
                        stat = if p.hasSrcFile then p.srcFileStat else p.execFileStat
                        if stat?
                            new Date(stat.mtime).getTime()
                        else
                            0
                )
        allExecutableSortedByMt = _.filter(allSortedByMt, (p) -> p.hasExecFile)

        if indexFilter?
            for filter, i in indexFilter
                arr =
                    if filter.type is 'mt'
                        allSortedByMt
                    else if filter.type is 'mtexec'
                        allExecutableSortedByMt
                    else
                        @all

                index = if filter.index < 0 then arr.length + filter.index else filter.index

                indexFilter[i] = @all.indexOf(arr[index])

            @all = (elem for elem, i in @all when i in indexFilter)

        @original = null unless @all[0]?.isOriginal
        @others = []

        for program, i in @all
            @all[i].setIndex i

            if not program.isOriginal
                @others.push program

    compile: -> program.compile() for program in @all


# Testing code
###
piFamily = new ProgramFamily("/home/albert/Dropbox/UPC/FIB/6eQuatri/PCA/Lab/sessio3/lab3_session/pi/pi.Fgspg")
console.log piFamily
piFamily.compile()
###
