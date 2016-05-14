_ = require 'lodash'
path = require 'path'
assert = require 'assert'
hasbin = require 'hasbin'

{ getFileInfo, attempt, execSync, hasLaterModificationTime, isExecutable } = require './utils'
SRC_EXTENSIONS = require './source-extensions'
ListString = require './list-string'
logger = require './logger'
styler = require './styler'
ProgramTiming = require './program-timing'

COMPILER_FLAGS = require './compiler-flags'

module.exports = class Program
    getExecFileInfo = (execFile) ->
        { dir, name, ext: extension } = path.parse execFile
        extension = extension[1..] # Remove dot

        # If file is name.ext1.ext2 then the parsed ext is '.ext1' and name is
        # 'name.ext1', but we need name to be 'name' and ext to be '.ext1.ext2'
        firstDotIndex = name.indexOf '.'
        if firstDotIndex isnt -1
            extension = name[firstDotIndex+1...] + extension
            name = name[0...firstDotIndex]

        # TODO: Maybe exit and print error if isn't executable??

        execStat = if isExecutable execFile then getFileInfo(execFile) else null
        { name: path.join(dir, name), extension, execFileStat: execStat }

    getSrcFileInfo = (programName) ->
        for srcExtension, { compiler, language } of SRC_EXTENSIONS
            srcFile = "#{programName}.#{srcExtension}"
            srcFileStat = getFileInfo srcFile
            return { srcFile, srcFileStat, srcExtension, compiler, language } if srcFileStat?

        {}

    addHelper = (where, argspec) ->
        assert(_.isString(argspec), "Argument argspec must be a string")

        info = argspec.split ":"

        add = (who, what) ->
            if where[who]?
                where[who].pushBack what
            else
                where[who] = new ListString(what)

        if info.length is 1
            add 'all', argspec
        else
            [specificationStr, what] = info

            if specificationStr.length is 0 or 'all' in specification = specificationStr.split ","
                add 'all', what
            else
                for program in _.uniq specification
                    if isNaN(program) or not _.isLength(Number(program))
                        logger.w "#{program} is not a valid program specifier, should be natural number, ignoring..."
                    else
                        add program, what


    calculateArguments = (programIndex) =>
        argsAll = @argumentsByProgram.all ? ""
        argsProg = @argumentsByProgram[programIndex] ? ""

        (new ListString argsAll, argsProg).toString()

    calculateCompilationFlags = (execFile, ext, programIndex, isGuessed) =>
        invalidFlag = (flag) =>
            unless isGuessed
                logger.w "Ignoring flag description #{flag} (#{styler.id execFile})..."
            else ""

        ext = ext.toLowerCase() # Get rid of the dot and put to lowercase

        flagString = new ListString()
        for flagName in ext.split('.')
            initialMatching = _.size(COMPILER_FLAGS)
            currentMatchingFlags = {}
            i = longestMatchingFlag = nMatching = undefined
            valid = true

            do resetInfo = ->
                # Create matching flags set, initially all flags match
                currentMatchingFlags[flag] = true for flag of COMPILER_FLAGS
                # Initialize counter of total matching flags
                nMatching = initialMatching
                i = 0
                longestMatchingFlag = null

            original = flagName
            currFlagString = new ListString()

            while i < flagName.length
                for flag of currentMatchingFlags when flag[i] isnt flagName[i]
                    delete currentMatchingFlags[flag]
                    --nMatching

                ++i
                for flag of currentMatchingFlags when flag.length is i
                    longestMatchingFlag = flag
                    break

                if nMatching is 1
                    flagMatching = _.keys(currentMatchingFlags)[0]
                    if flagMatching[i..] isnt flagName[i...flagMatching.length]
                        invalidFlag original
                        valid = false
                        break
                    flagName = flagName[flagMatching.length..]
                    resetInfo()
                    currFlagString.pushBack(COMPILER_FLAGS[flagMatching])
                else if nMatching is 0
                    if longestMatchingFlag?
                        currFlagString.pushBack(COMPILER_FLAGS[longestMatchingFlag])
                        flagName = flagName[longestMatchingFlag.length..]
                        resetInfo()
                    else
                        invalidFlag original
                        valid = false
                        break

            if flagName.length > 0 and valid
                if longestMatchingFlag?
                    currFlagString.pushBack(COMPILER_FLAGS[longestMatchingFlag])
                else
                    invalidFlag original
                    valid = false

            if valid
                flagString.pushBack(currFlagString)

        flagString.pushBack(@flagsByProgram.all ? "",
                            @flagsByProgram[programIndex] ? "")

        flagString.toString()

    shouldCompile = (program) ->
        program.hasSrcFile and
        (
            not program.hasExecFile or
            hasLaterModificationTime(program.srcFileStat, program.execFileStat)
        )

    @currentIndex: 0
    @argumentsByProgram: {}
    @flagsByProgram: {}

    @addArguments: _.partial(addHelper, Program.argumentsByProgram)

    @addFlags: _.partial(addHelper, Program.flagsByProgram)

    constructor: (@execFile, { @isGuessed = no, @isOriginal = no } = {}) ->
        assert _.isString(@execFile), "Executable file is not a String"

        { @name, extension: @execExtension, @execFileStat } = getExecFileInfo @execFile
        { @srcFile, @srcFileStat, @srcExtension, @compiler, @language } = getSrcFileInfo @name

        @hasSrcFile =  @srcFileStat?
        @hasExecFile = @execFileStat?
        @hasBinaryInPath = hasbin.sync @execFile
        @index = Program.currentIndex++

        @arguments = calculateArguments @index
        @compilationFlags = calculateCompilationFlags @execFile, @execExtension, @index, @isGuessed

        @command = new ListString(@execFile, @arguments).toString()

    compile: (explicitlyDemanded = no) ->
        unless @hasSrcFile or @hasExecFile
            logger.e "Couldn't compile #{styler.id @execFile} because no
                      source file nor executable was found for program",
                     { exit: yes, printStack: no }

        unless @hasSrcFile
            if explicitlyDemanded
                logger.w "Couldn't compile #{styler.id @execFile}, which has already an executable,
                          because no source file was found for the program"
            return

        unless shouldCompile @
            logger.v "#{@execFile} is already up to date"; return

        command = new ListString(@compiler, @srcFile, @compilationFlags, "-o",
                                 @execFile).toString()

        logger.i "Compiling... #{styler.cmd command}"

        { stderr } = attempt execSync, command

        logger.n stderr if stderr?.length > 0 # Probably warnings from compiler

        @hasExecFile = yes

    time: -> @timing = new ProgramTiming(@)

    ensureExecutable: ->
        unless @isGuessed or @hasExecFile or @hasBinaryInPath
            unless @hasSrcFile
                logger.e "Program #{styler.id @execFile} doesn't exist or isn't executable"
            else
                logger.e "Program #{styler.id @execFile} isn't compiled"

        @hasExecFile or @hasBinaryInPath

    toString: -> @command




# Testing code
###
timer = new Program "/home/albert/Dropbox/UPC/FIB/6eQuatri/PCA/Lab/sessio3/lab3_session/pi/pi.3g.StaTic.Pg"
console.log timer
timer = new Program "/home/albert/Dropbox/UPC/FIB/6eQuatri/PCA/Lab/sessio3/lab3_session/pi/pi.3gspg"
console.log timer
timer = new Program "/home/albert/Dropbox/UPC/FIB/6eQuatri/PCA/Lab/sessio3/lab3_session/pi/pi.3gS"
console.log timer
timer = new Program "./pi.3"
timer.compile()
# Should crash
timer = new Program "/home/albert/Dropbox/UPC/FIB/6eQuatri/PCA/Lab/sessio3/lab3_session/pi/pi.3gStaTiocPg"
###
