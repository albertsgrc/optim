{ Studentt } = require 'distributions'
chalk = require 'chalk256'
fs = require 'fs'

ProgramFamily = require './program-family'
ProgramTiming = require './program-timing'
logger = require './logger'
{ prettyDecimal, compartimentedString, attemptShell } = require './utils'
styler = require './styler'
{ DFL_DECIMAL_PLACES: DECIMALS, DFL_CONFIDENCE_RATE, CSV_OUTPUT_FOLDER } = require './constants'

SPACES_BY_COL = [
    10
    Math.max(11, 5 + DECIMALS)
    Math.max(3, 6 + DECIMALS)
    Math.max(11, 6 + DECIMALS)
    Math.max(7, 6 + DECIMALS)
    6
    Math.max(6, 6 + DECIMALS)
    4
]

isFaster = ({ cpu: meanOpt,  repetitions: repsOpt,  cpuVariance: varianceOpt },
            { cpu: meanOriginal, repetitions: repsOriginal, cpuVariance: varianceOriginal}, confidence) ->
    freedom = repsOpt + repsOriginal - 2

    return undefined if freedom <= 0

    mean = meanOpt - meanOriginal
    dist = new Studentt(freedom)

    commonVariance = ( (repsOpt - 1)*varianceOpt + (repsOriginal - 1)*varianceOriginal )/freedom;
    fac = Math.sqrt(commonVariance*(1/repsOpt + 1/repsOriginal))

    t = mean/fac

    dist.cdf(t) < confidence

toSecs = (micros) -> prettyDecimal(micros*1e-6, DECIMALS)

prettyMemory = (kb) ->
    unit = null
    value = null
    if kb >= 1e6 # Giga
        unit = "GB"
        value = prettyDecimal(kb*1e-6, DECIMALS)
    else if kb >= 1e3 # Mega
        unit = "MB"
        value = prettyDecimal(kb*1e-3, DECIMALS)
    else
        unit = "KB"
        value = kb

    styler.value(value) + styler.unit(unit)

prettySpeedup = (speedup) ->
    s = styler.value prettyDecimal(speedup)

    if speedup < 0.5
        styler.veryBad s
    else if speedup < 0.9
        styler.insuficient s
    else if speedup < 1.1
        styler.regular s
    else if speedup < 1.5
        styler.ok s
    else if speedup < 2
        styler.good s
    else if speedup < 2.5
        styler.nice s
    else if speedup < 3
        styler.veryGood s
    else
        styler.superNice s

@time = (original, others, { forceRepetitions
                             repetitions
                             timeLimit
                             setHighPriority
                             instrumented
                             confidenceRate = DFL_CONFIDENCE_RATE
                             all = no
                             first = no
                             previous = no
                             csv = no
                           } = {}) ->
    ProgramTiming.configure({ forceRepetitions, repetitions, timeLimit, setHighPriority, instrumented })

    timings = []

    indexFilter =
        unless all
            if first
                [ { index: 0 }, { type: 'mtexec', index: -1 } ]
            else
                [ { type: 'mtexec', index: -2 }, { type: 'mtexec', index: -1 } ]

    programs = new ProgramFamily original, others, { indexFilter }

    unless all
        programs.original ?= programs.others.shift()

    unless programs.original?
        logger.w("No program was found matching #{styler.id original}")
        process.exit 0

    return unless programs.original.ensureExecutable()


    logger.noTag compartimentedString(SPACES_BY_COL,
                                      { value: chalk.bold("Is faster?") }
                                      { value: chalk.bold("CPU Speedup") }
                                      { value: chalk.bold("CPU") }
                                      { value: chalk.bold("Elp Speedup") }
                                      { value: chalk.bold("Elapsed") }
                                      { value: chalk.bold("CPU%") }
                                      { value: chalk.bold("Memory") }
                                      { value: chalk.bold("Reps") })

    speedupModel = programs.original.time()
    speedupModel.cpu_s = speedupModel.elp_s = 1

    timings.push speedupModel

    logger.noTag compartimentedString(SPACES_BY_COL,
                                      { value: styler.normal("N/A"), padKind: "Start" },
                                      { value: styler.normal("N/A") },
                                      { value: "#{styler.value(toSecs(speedupModel.cpu))}#{styler.unit 's'}" },
                                      { value: styler.normal("N/A") },
                                      { value: "#{styler.value(toSecs(speedupModel.elapsed))}#{styler.unit 's'}" }
                                      { value: "#{styler.value(prettyDecimal(speedupModel.cpu_ratio, 2))}#{styler.unit '%'}" }
                                      { value: "#{prettyMemory speedupModel.mem_max}" },
                                      { value: "#{styler.value speedupModel.repetitions}" })



    for program in programs.others
        continue unless program.ensureExecutable()

        timing = program.time()

        continue unless timing.success

        isFasterThanOriginal = isFaster timing, speedupModel, confidenceRate
        cpuSpeedup = timing.cpu_s = speedupModel.cpu/timing.cpu
        elpSpeedup = timing.elp_s = speedupModel.elapsed/timing.elapsed

        timings.push timing

        speedupModel = timing if previous

        fasterString =
            if isFasterThanOriginal?
                if isFasterThanOriginal
                    styler.okay('FASTER')
                else
                    styler.bad('NOT FASTER')
            else
                styler.normal('UNKNOWN')

        logger.noTag compartimentedString(SPACES_BY_COL,
                                          { value: chalk.bold(fasterString), padKind: "Start" },
                                          { value: "#{prettySpeedup cpuSpeedup}" },
                                          { value: "#{styler.value(toSecs(timing.cpu))}#{styler.unit 's'}" },
                                          { value: "#{prettySpeedup elpSpeedup }", space: SPACES_BY_COL[3] }
                                          { value: "#{styler.value(toSecs(timing.elapsed))}#{styler.unit 's'}" }
                                          { value: "#{styler.value(prettyDecimal(timing.cpu_ratio, 2))}#{styler.unit '%'}" }
                                          { value: "#{prettyMemory timing.mem_max}" },
                                          { value: "#{styler.value timing.repetitions}" })

    if csv
        csv = "#{new Date().getTime()}.csv" if csv is yes

        csvString = "data,#{(program.execFile for program in programs.all).join(",")}\n"

        for prop in ['user', 'sys', 'cpu', 'elapsed', 'repetitions', 'cpu_s', 'elp_s', 'mem_max', 'cpu_ratio']
            csvString += "#{prop},#{(timing[prop] for timing in timings).join(",")}\n"

        attemptShell "mkdir", ['-p', CSV_OUTPUT_FOLDER]
        fs.writeFileSync "./#{CSV_OUTPUT_FOLDER}/#{csv}", csvString, { encoding: 'utf-8' }
