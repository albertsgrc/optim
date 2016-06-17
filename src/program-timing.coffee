logger = require './logger'
styler = require './styler'
ListString = require './list-string'
isRoot = do require('is-root')
{ attempt, execSync, hasProgramInstalled } = require './utils'
{ DFL_TIME_LIMIT, DFL_REPETITIONS } = require './constants'
TIMER_CMD = ["#{__dirname}/timer/timer", "-ni"]
TIMER_CMD_DONT_IGNORE = ["#{__dirname}/timer/timer", "-n"]

module.exports = class ProgramTiming
    @repetitions: DFL_REPETITIONS
    @timeLimit: DFL_TIME_LIMIT
    @forceRepetitions: no
    @stats: ['elapsed', 'user', 'sys', 'cpu', 'cpu_ratio', 'mem_max']
    @priorityCmd: ""
    tasksetCmd = if hasProgramInstalled 'taskset' then ['taskset', '-c', '1'] else ''

    @configure: ({ forceRepetitions
                   repetitions
                   timeLimit
                   setHighPriority
                 } = {}) ->
        @repetitions = Math.round Number(repetitions ? @repetitions)
        @timeLimit = Number(timeLimit ? @timeLimit) # in secs
        @forceRepetitions = forceRepetitions ? @forceRepetitions

        if setHighPriority
            unless isRoot
                logger.v("No root permissions: switching to nice command instead of chrt")

                if hasProgramInstalled 'nice'
                    ProgramTiming.priorityCmd = ['nice', '-19']
                else
                    logger.e "Program #{styler.id 'nice'} is needed to set the program execution to high priority"
            else
                if hasProgramInstalled 'chrt'
                    ProgramTiming.priorityCmd = ['chrt', '-f', '99']
                else
                    logger.e "Program #{styler.id 'chrt'} is needed to set the program execution to high priority"

        logger.e("Repetitions argument must be > 0", { exit: yes, printStack: no }) if @repetitions <= 0
        logger.e("Time limit argument must be > 0", { exit: yes, printStack: no }) if @timeLimit <= 0

    _timeExec: (i) ->
        timerCmd = if @program.hasOutput then TIMER_CMD_DONT_IGNORE else TIMER_CMD
        prolog = new ListString(ProgramTiming.priorityCmd, tasksetCmd, timerCmd).toString()
        result = attempt execSync, "#{prolog} #{@program.command}", { exit: no, printError: no }

        if result.isError
            logger.write(styler.error(" ERROR:") + " #{result.stderr?[...-1]}").endLine()
            process.exit 1 if @program.isOriginal
            return false

        result = if @program.hasOutput then result.stderr else result.stdout

        info = JSON.parse result
        info.cpu = info.user + info.sys
        info.cpu_ratio = 100*info.cpu/info.elapsed

        for prop, value of info
            delta = value - @[prop]
            @[prop] += delta/i
            @_m2[prop] += delta*(value - @[prop])

        true

    _updateProgress: (i) ->
        logger.updateInfo "Timing #{styler.cmd @program.toString()}... (#{i}/#{@repetitions ? '?'})"

    constructor: (@program) ->
        @_m2 = {}
        @[stat] = @[stat + 'Variance'] = @_m2[stat] = 0 for stat in ProgramTiming.stats

        @repetitions =
            if ProgramTiming.forceRepetitions or ProgramTiming.repetitions is 1
                ProgramTiming.repetitions
            else
                null

        @_updateProgress 1
        @success = @_timeExec(1)
        return null unless @success

        @repetitions ?= Math.max 1, Math.min(ProgramTiming.repetitions, (ProgramTiming.timeLimit*1e6//@elapsed))

        @_updateProgress 1 # So that the ? vanishes in case no more repetitions are needed

        for i in [2...@repetitions+1]
            @_updateProgress i
            @success = @_timeExec(i)
            return null unless @success

        if @repetitions <= 1
            @[stat + 'Variance'] = 0 for stat in ProgramTiming.stats
        else
            @[stat + 'Variance'] = @_m2[stat]/(@repetitions - 1) for stat in ProgramTiming.stats

        logger.updateInfo("#{styler.cmd @program.toString()}:").endLine()
