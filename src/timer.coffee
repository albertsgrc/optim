{ Studentt } = require 'distributions'
chalk = require 'chalk256'

ProgramFamily = require './program-family'
ProgramTiming = require './program-timing'
logger = require './logger'
{ prettyDecimal, compartimentedString } = require './utils'
styler = require './styler'

DFL_CONFIDENCE_RATE = 0.05
DECIMALS = 3

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

    styler.value(value) + unit

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
                             confidenceRate = DFL_CONFIDENCE_RATE
                             last = no
                           } = {}) ->
    ProgramTiming.configure({ forceRepetitions, repetitions, timeLimit })

    programs = new ProgramFamily original, others, { last }

    return unless programs.original.ensureExecutable()

    logger.noTag compartimentedString({ value: chalk.bold("Is faster?"),  space: 10 },
                                      { value: chalk.bold("Speedup"),     space: Math.max(7, 2 + DECIMALS) },
                                      { value: chalk.bold("CPU"),         space: 3 + DECIMALS },
                                      { value: chalk.bold("Memory"),      space: Math.max(6, 4 + DECIMALS) },
                                      { value: chalk.bold("Repetitions"), space: 11 })

    originalTiming = programs.original.time()

    logger.noTag compartimentedString({ value: "", space: 10 },
                                      { value: "", space: Math.max(7, 2 + DECIMALS) },
                                      { value: "#{styler.value(toSecs(originalTiming.cpu))}s", space: 3 + DECIMALS },
                                      { value: "#{prettyMemory originalTiming.mem_max}", space: Math.max(6, 4 + DECIMALS) },
                                      { value: "#{styler.value originalTiming.repetitions}", space: 11 })

    for program in programs.others
        continue unless program.ensureExecutable()

        timing = program.time()

        continue unless timing.success

        isFasterThanOriginal = isFaster timing, originalTiming, confidenceRate
        speedup = originalTiming.cpu/timing.cpu

        fasterString =
            if isFasterThanOriginal?
                if isFasterThanOriginal
                    styler.okay('FASTER')
                else
                    styler.bad('NOT FASTER')
            else
                styler.normal('UNKNOWN')

        logger.noTag compartimentedString({ value: chalk.bold(fasterString), space: 10, padKind: "Start" },
                                          { value: "#{prettySpeedup speedup}", space: Math.max(7, 2 + DECIMALS) },
                                          { value: "#{styler.value(toSecs(timing.cpu))}s", space: 3 + DECIMALS },
                                          { value: "#{prettyMemory timing.mem_max}", space: Math.max(6, 4 + DECIMALS) },
                                          { value: "#{styler.value timing.repetitions}", space: 11 })
