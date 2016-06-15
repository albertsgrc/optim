fs = require 'fs'
path = require 'path'

{ attemptShell, attempt, execSync } = require './utils'
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
                               } = {}) ->
    unless attemptShell('which', 'objdump')?
        logger.e "Program #{styler.id 'objdump'} is required for this command.", { exit: yes, printStack: no }

    programs = new ProgramFamily original, others

    unless all
        programs.all = programs.allExecutableSortedByMt[-1..]

    unless programs.all.length
        logger.w("No program was found matching #{styler.id original}")
        process.exit 0

    for program in programs.all
        continue unless program.hasExecFile

        cmd = new ListString('objdump', (if pretty then '-S' else ''), '-d', program.execFile).toString()

        logger.i "Assembly of #{styler.id program.execFile}:"

        result = attempt execSync, cmd, { exit: no }

        continue if result.isError

        logger.noTag result.stdout

        if saveFile
            if saveFile is yes
                saveFile = "#{program.execFile}_#{new Date().getTime()}.s"

            attemptShell "mkdir", ['-p', ASSEMBLY_OUTPUT_FOLDER]

            outPath = path.join ASSEMBLY_OUTPUT_FOLDER, saveFile

            fs.writeFileSync(outPath, result.stdout, { encoding: 'utf-8' })
