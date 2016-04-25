assert = require 'assert'
_ = require 'lodash'
path = require 'path'
utils = require './utils'

{ getFileInfo, attempt, execSync, hasLaterModificationTime } = require './utils'
SRC_EXTENSIONS = require './source-extensions'
ListString = require './list-string'
logger = require './logger'
styler = require './styler'

COMPILER_FLAGS = require './compiler-flags'

module.exports = class Program
    getExecFileInfo = (execFile) ->
        { dir, name, ext: extension } = path.parse execFile

        # If file is name.ext1.ext2 then the parsed ext is '.ext1' and name is
        # 'name.ext1', but we need name to be 'name' and ext to be '.ext1.ext2'
        firstDotIndex = name.indexOf '.'
        if firstDotIndex isnt -1
            extension = name[firstDotIndex...] + extension
            name = name[0...firstDotIndex]

        execStat = if utils.isBinaryExecutable execFile then getFileInfo(execFile) else null
        { name: path.join(dir, name), extension, execFileStat: execStat }

    getSrcFileInfo = (programName) ->
        for srcExtension, { compiler, language } of SRC_EXTENSIONS
            srcFile = "#{programName}.#{srcExtension}"
            srcFileStat = getFileInfo srcFile
            return { srcFile, srcFileStat, srcExtension, compiler, language } if srcFileStat?

        {}

    addHelper = (where, what, who = 'all') ->
        assert(_.isString(who) or _.isLength(who),
               "Argument who must be a string or positive integer")

        if where[who]?
            where[who].pushBack what
        else
            where[who] = new ListString(what)

    calculateArguments = (programIndex) =>
        argsAll = @argumentsByProgram.all ? ""
        argsProg = @argumentsByProgram[programIndex] ? ""

        (new ListString argsAll, argsProg).toString()

    calculateCompilationFlags = (execFile, ext, programIndex, isGuessed) =>
        invalidFlag = (flag) =>
            unless isGuessed
                logger.e "Invalid compiler flag description #{flag} (#{styler.id execFile})", exit: yes, printStack: no
            else ""

        ext = ext[1..].toLowerCase() # Get rid of the dot and put to lowercase

        if ext.indexOf('.') isnt -1 # Format name.g.pg.o3
            flags = []
            for flagName in ext.split('.')
                if COMPILER_FLAGS[flagName]?
                    flags.push COMPILER_FLAGS[flagName]
                else
                    return invalidFlag flagName
            flagString = new ListString(flags)
        else # Format name.gpgo3
            initialMatching = _.size(COMPILER_FLAGS)
            currentMatchingFlags = {}
            flagString = new ListString()
            i = longestMatchingFlag = nMatching = undefined

            do resetInfo = ->
                # Create matching flags set, initially all flags match
                currentMatchingFlags[flag] = true for flag of COMPILER_FLAGS
                # Initialize counter of total matching flags
                nMatching = initialMatching
                i = 0
                longestMatchingFlag = null

            while i < ext.length
                for flag of currentMatchingFlags when flag[i] isnt ext[i]
                    delete currentMatchingFlags[flag]
                    --nMatching

                ++i
                for flag of currentMatchingFlags when flag.length is i
                    longestMatchingFlag = flag
                    break

                if nMatching is 1
                    flagMatching = _.keys(currentMatchingFlags)[0]
                    return invalidFlag ext if flagMatching[i..] isnt ext[i...flagMatching.length]
                    ext = ext[flagMatching.length..]
                    resetInfo()
                    flagString.pushBack(COMPILER_FLAGS[flagMatching])
                else if nMatching is 0
                    if longestMatchingFlag?
                        flagString.pushBack(COMPILER_FLAGS[longestMatchingFlag])
                        ext = ext[longestMatchingFlag.length..]
                        resetInfo()
                    else
                        return invalidFlag ext

            if ext.length > 0
                if longestMatchingFlag?
                    flagString.pushBack(COMPILER_FLAGS[longestMatchingFlag])
                else
                    return invalidFlag ext

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

    constructor: (@execFile, { @isGuessed = no } = {}) ->
        assert _.isString(@execFile), "Executable file is not a String"

        { @name, extension: @execExtension, @execFileStat } = getExecFileInfo @execFile
        { @srcFile, @srcFileStat, @srcExtension, @compiler, @language } = getSrcFileInfo @name

        @hasSrcFile =  @srcFileStat?
        @hasExecFile = @execFileStat?
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

    ensureExecutable: ->
        unless @hasExecFile
            unless @hasSrcFile
                logger.e "Program #{styler.id @execFile} doesn't exist or isn't readable"
            else
                logger.e "Program #{styler.id @execFile} isn't compiled"

            false
        else true




# Testing code
###
timer = new Program "/home/albert/Dropbox/UPC/FIB/6eQuatri/PCA/Lab/sessio3/lab3_session/pi/pi.3gStaTicPg"
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
