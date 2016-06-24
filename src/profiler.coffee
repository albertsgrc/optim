fs = require 'fs'
path = require 'path'
_ = require 'lodash'

ProgramFamily = require './program-family'
{ attemptShell, attempt, execSync, hasProgramInstalled, optionAddHelper } = require './utils'
logger = require './logger'
styler = require './styler'
ListString = require './list-string'
{ OPERF_EVENTS, PROFILING_OUTPUT_FOLDER } = require './constants'

module.exports = @

@OPERF_EVENTS_REGEX = new RegExp "^(#{(key for key of OPERF_EVENTS).join('|')})$"

profilingOptions = {}

@addProfilingOption = _.partial optionAddHelper, profilingOptions

@profile = (original, others, {
                                event = 'cycles'
                                assembly = no
                                gprof = no
                                clean = yes
                                saveFile = no
                                all = no
                                literal
                                counter
                              } = {}) ->
    if gprof
        unless hasProgramInstalled 'gprof'
            logger.e "Program #{styler.id 'gprof'} is required for this command.", { exit: yes, printStack: no }
    else
        unless hasProgramInstalled 'operf'
            logger.e "Program #{styler.id 'operf'} is required for this command.", { exit: yes, printStack: no }
        unless hasProgramInstalled 'opannotate'
            logger.e "Program #{styler.id 'opannotate'} is required for this command.", { exit: yes, printStack: no }


    indexFilter =
        unless all
            [ { type: 'mtexec', index: -1 }]

    programs = new ProgramFamily original, others, { indexFilter, shouldGuess: literal }

    unless programs.all.length
        logger.w("No program was found matching #{styler.id original}")
        process.exit 0

    for program in programs.all
        continue unless program.ensureExecutable()

        profilerArgs = new ListString profilingOptions.all ? "", profilingOptions[program.index] ? ""

        if gprof
            # Try to generate gmon.out file
            attempt execSync, program.command, { exit: no }
            # Check that gmon.out has been generated
            if attemptShell('ls').indexOf('gmon.out') is -1
                logger.e "Program #{styler.id program.command} didn't generate a gmon.out file. Maybe you didn't compile it with -pg option?"
                continue

            gprofCmd = new ListString("gprof", "-b", profilerArgs, program.execFile).toString()

            logger.i "Profiling #{styler.cmd gprofCmd}..."

            result = attempt execSync, gprofCmd.toString(), { exit: no }
        else
            eventName = OPERF_EVENTS[event].event
            eventCount = if counter? then counter else OPERF_EVENTS[event].counter
            operfCmd = new ListString("operf", "--event=#{eventName}:#{eventCount}", profilerArgs).toString()
            cmd = "#{operfCmd} #{program.command}"

            logger.i "Profiling #{styler.cmd cmd}..."

            operfRes = attempt execSync, cmd, { exit: no }
            continue if operfRes.isError

            opannotateCmd = new ListString("opannotate", (if assembly then "--assembly" else "--source"), program.execFile).toString()

            logger.i "Annotating #{styler.cmd opannotateCmd}..."

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
