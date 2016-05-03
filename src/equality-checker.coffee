os = require 'os'
uniqueFilename = require 'unique-filename'

{ execSync, attempt, attemptShell } = require './utils'
ProgramFamily = require './program-family'
styler = require './styler'
logger = require './logger'

module.exports = @

@check = (original, others, { last = no } = {}) ->
    programFamily = new ProgramFamily original, others, { last }

    # Check that all programs are executable

    return unless programFamily.original.ensureExecutable()

    unless programFamily.others.length > 0
        logger.w("No program was found to compare with #{styler.id original}")
        process.exit 0

    outputFileOriginal = uniqueFilename os.tmpDir()

    logger.i "Executing original program #{styler.id programFamily.original.command}..."

    attempt execSync, "#{programFamily.original.command} > #{outputFileOriginal}"
    for program in programFamily.others
        continue unless program.ensureExecutable()

        outputFile = uniqueFilename os.tmpDir()

        logger.i "Checking #{styler.id program.command}... ", endline: no

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
            logger.write(styler.error("error:") + " #{res.stderr?[...-1]}").endLine()

        attemptShell 'rm', outputFile

    attemptShell 'rm', outputFileOriginal
