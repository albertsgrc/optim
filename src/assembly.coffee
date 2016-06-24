fs = require 'fs'
path = require 'path'

{ attemptShell, attempt, execSync, hasProgramInstalled } = require './utils'
logger = require './logger'
styler = require './styler'
ProgramFamily = require './program-family'
{ ASSEMBLY_OUTPUT_FOLDER } = require './constants'
ListString = require './list-string'

module.exports = @

@assembly = (original, others, {
                                pretty = no
                                all = no
                                saveFile = no
                                literal
                               } = {}) ->
    unless hasProgramInstalled 'objdump'
        logger.e "Program #{styler.id 'objdump'} is required for this command.", { exit: yes, printStack: no }

    indexFilter =
        unless all
            [ { type: 'mtexec', index: -1 }]

    programs = new ProgramFamily original, others, { indexFilter, shouldGuess: literal }

    unless programs.all.length
        logger.w("No program was found matching #{styler.id original}")
        process.exit 0

    for program in programs.all
        continue unless program.hasExecFile

        cmd = new ListString('objdump', (if pretty then '-S' else ''), '-d', program.execFile).toString()

        logger.i "Retrieving assembly #{styler.cmd cmd}...:"

        result = attempt execSync, cmd, { exit: no }

        continue if result.isError

        if saveFile
            file =
                if saveFile is yes
                    "#{program.execFile}_#{new Date().getTime()}.s"
                else
                    saveFile

            attemptShell "mkdir", ['-p', ASSEMBLY_OUTPUT_FOLDER]

            outPath = path.join ASSEMBLY_OUTPUT_FOLDER, file

            fs.writeFileSync(outPath, result.stdout, { encoding: 'utf-8' })

            logger.i "Assembly written to file #{styler.id outPath}"
        else
            logger.noTag result.stdout
