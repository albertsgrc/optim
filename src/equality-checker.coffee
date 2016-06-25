os = require 'os'
path = require 'path'
fs = require 'fs'
uniqueFilename = require 'unique-filename'

{ execSync, attempt, attemptShell, normalizeError } = require './utils'
ProgramFamily = require './program-family'
styler = require './styler'
logger = require './logger'

@check = (original, others, { all = no, custom = no } = {}) ->
    indexFilter =
        unless all
            [ { index: 0 }, { type: 'mtexec', index: -1 } ]

    programs = new ProgramFamily original, others, { indexFilter }

    unless all
        programs.original ?= programs.others.shift()

    # Check that all programs are executable

    return unless programs.original.ensureExecutable()

    unless programs.others.length > 0
        logger.w("No program was found to compare with #{styler.id original}")
        process.exit 0

    outputFileOriginal = uniqueFilename os.tmpDir()

    logger.i "Executing original program #{styler.id programs.original.toString()}..."

    attempt execSync, "#{programs.original.command} > #{outputFileOriginal}"
    for program in programs.others
        continue unless program.ensureExecutable()

        outputFile = uniqueFilename os.tmpDir()

        logger.i "Checking #{styler.id program.toString()}... ", endline: no

        res = attempt execSync, "#{program.command} > #{outputFile}",
                      { exit: no, printError: no }

        unless res.isError
            if custom is no
                res = attempt execSync, "cmp #{outputFileOriginal} #{outputFile}", exit: no, printError: no
                if res.isError
                    if res.status is 1 # Files differ
                        error = if res.stderr?.length then res.stderr[...-1] else res.stdout?[...-1]
                        logger.write(styler.bad("not okay") + ": #{error}").endLine()
                    else # Another unknown error
                        logger.write(styler.warn("couldn't check") + ": #{normalizeError res.stderr}").endLine()
                else # equal
                    logger.write(styler.okay("okay")).endLine()
            else
                try
                    customEqualityChecker = require path.join(process.cwd(), custom)
                catch error
                    logger.e "An error occurred while requiring your custom equality checker: #{error.toString()}", { exit: yes, printStack: no }

                if typeof customEqualityChecker.eq is "function"
                    outputOriginal = fs.readFileSync(outputFileOriginal, encoding: 'utf-8')
                    outputNew = fs.readFileSync(outputFile, encoding: 'utf-8')
                    { equal: outputsEqual, message } = customEqualityChecker.eq outputOriginal, outputNew

                    if outputsEqual
                        logger.write(styler.okay("okay"))
                    else
                        logger.write(styler.bad("not okay"))

                    if message?.length > 0
                        logger.write ": #{message}"

                    logger.endLine()
                else
                    logger.e "Your custom equality checker doesn't define an eq method", { exit: yes, printStack: no }
        else # Error while executing the program
            logger.write(styler.error(" ERROR:") + " #{normalizeError res.stderr}").endLine()

        attemptShell 'rm', outputFile

    attemptShell 'rm', outputFileOriginal
