os = require 'os'
uniqueFilename = require 'unique-filename'

{ execSync, attempt, attemptShell } = require './utils'
ProgramFamily = require './program-family'
styler = require './styler'
logger = require './logger'

@check = (original, others, { last = no } = {}) ->
    programs = new ProgramFamily original, others

    # Check that all programs are executable

    return unless programs.original.ensureExecutable()

    unless programs.others.length > 0
        logger.w("No program was found to compare with #{styler.id original}")
        process.exit 0

    if last
        programs.others = programs.allSortedByMt[-1..]

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
            res = attempt execSync, "cmp #{outputFileOriginal} #{outputFile}", exit: no, printError: no
            if res.isError
                if res.status is 1 # Files differ
                    error = if res.stderr?.length then res.stderr[...-1] else res.stdout?[...-1]
                    logger.write(styler.bad("not okay") + ": #{error}").endLine()
                else # Another unknown error
                    logger.write(styler.warn("couldn't check") + ": #{res.stderr?[...-1]}").endLine()
            else # equal
                logger.write(styler.okay("okay")).endLine()
        else # Error while executing the program
            logger.write(styler.error(" ERROR:") + " #{res.stderr?[...-1]}").endLine()

        attemptShell 'rm', outputFile

    attemptShell 'rm', outputFileOriginal
