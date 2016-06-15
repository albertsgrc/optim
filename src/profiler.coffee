fs = require 'fs'
path = require 'path'

ProgramFamily = require './program-family'
{ attemptShell, attempt, execSync } = require './utils'
logger = require './logger'
styler = require './styler'
ListString = require './list-string'
{ OPERF_EVENTS, PROFILING_OUTPUT_FOLDER } = require './constants'

module.exports = @

@OPERF_EVENTS_REGEX = new RegExp "^(#{(key for key of OPERF_EVENTS).join('|')})$"

profilingOptions = []

@addProfilingOption = (option) -> profilingOptions.push(option)

@profile = (original, others, {
                                event = 'cycles'
                                assembly = no
                                gprof = no
                                clean = yes
                                saveFile = no
                                all = no
                                counter
                              } = {}) ->
    programs = new ProgramFamily original, others

    unless all
        programs.all = programs.allExecutableSortedByMt[-1..]

    unless programs.all.length
        logger.w("No program was found matching #{styler.id original}")
        process.exit 0

    for program in programs.all
        continue unless program.ensureExecutable()

        if gprof
            # Try to generate gmon.out file
            attempt execSync, program.command, { exit: no }
            # Check that gmon.out has been generated
            if attemptShell('ls').indexOf('gmon.out') is -1
                logger.e "Program #{styler.id program.command} didn't generate a gmon.out file. Maybe you didn't compile it with -pg option?"
                continue

            gprofCmd = new ListString("gprof", "-b", profilingOptions, program.execFile).toString()

            logger.i "Profiling #{gprofCmd}..."

            result = attempt execSync, gprofCmd.toString(), { exit: no }
        else
            eventName = OPERF_EVENTS[event].event
            eventCount = if counter? then counter else OPERF_EVENTS[event].counter
            operfCmd = new ListString("operf", "--event=#{eventName}:#{eventCount}").toString()
            cmd = "#{operfCmd} #{program.command}"

            logger.i "Profiling #{cmd}..."

            operfRes = attempt execSync, cmd, { exit: no }
            continue if operfRes.isError

            opannotateCmd = new ListString("opannotate", (if assembly then "--assembly" else "--source"), program.execFile).toString()

            logger.i "Annotating #{opannotateCmd}..."

            result = attempt execSync, opannotateCmd, { exit: no }

        unless result.isError
            logger.noTag result.stdout

            if saveFile
                if saveFile is yes
                    profileMark = if gprof then "gprof" else "ann"
                    saveFile = "#{program.execFile}_#{new Date().getTime()}.#{profileMark}.txt"

                attemptShell "mkdir", ['-p', PROFILING_OUTPUT_FOLDER]

                outPath = path.join PROFILING_OUTPUT_FOLDER, saveFile

                fs.writeFileSync(outPath, result.stdout, { encoding: 'utf-8' })


    if clean
        attemptShell('rm', ['-rf', 'oprofile_data', 'gmon.out'])
