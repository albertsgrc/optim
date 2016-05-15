{ Studentt } = require 'distributions'
chalk = require 'chalk256'

ProgramFamily = require './program-family'
ProgramTiming = require './program-timing'
logger = require './logger'
{ prettyDecimal, compartimentedString } = require './utils'
styler = require './styler'

DFL_CONFIDENCE_RATE = 0.05
DECIMALS = 3
SPACES_BY_COL = [10, Math.max(11, 5 + DECIMALS), Math.max(3, 6 + DECIMALS), Math.max(11, 6 + DECIMALS), Math.max(7, 6 + DECIMALS), 6, Math.max(6, 6 + DECIMALS), 4]

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
                             confidenceRate = DFL_CONFIDENCE_RATE
                             last = no
                           } = {}) ->
    ProgramTiming.configure({ forceRepetitions, repetitions, timeLimit })

    programs = new ProgramFamily original, others, { last }

    return unless programs.original.ensureExecutable()

    logger.noTag compartimentedString({ value: chalk.bold("Is faster?"),  space: SPACES_BY_COL[0] }
                                      { value: chalk.bold("CPU Speedup"), space: SPACES_BY_COL[1] }
                                      { value: chalk.bold("CPU"),         space: SPACES_BY_COL[2] }
                                      { value: chalk.bold("Elp Speedup"), space: SPACES_BY_COL[3] }
                                      { value: chalk.bold("Elapsed"),     space: SPACES_BY_COL[4] }
                                      { value: chalk.bold("CPU%"),        space: SPACES_BY_COL[5] }
                                      { value: chalk.bold("Memory"),      space: SPACES_BY_COL[6] }
                                      { value: chalk.bold("Reps"), space: SPACES_BY_COL[7] })

    originalTiming = programs.original.time()

    logger.noTag compartimentedString({ value: styler.normal("N/A"), space: SPACES_BY_COL[0], padKind: "Start" },
                                      { value: styler.normal("N/A"), space: SPACES_BY_COL[1] },
                                      { value: "#{styler.value(toSecs(originalTiming.cpu))}#{styler.unit 's'}", space: SPACES_BY_COL[2] },
                                      { value: styler.normal("N/A"), space: SPACES_BY_COL[3] },
                                      { value: "#{styler.value(toSecs(originalTiming.elapsed))}#{styler.unit 's'}", space: SPACES_BY_COL[4]}
                                      { value: "#{styler.value(prettyDecimal(originalTiming.cpu_ratio, 2))}#{styler.unit '%'}", space: SPACES_BY_COL[5] }
                                      { value: "#{prettyMemory originalTiming.mem_max}", space: SPACES_BY_COL[6] },
                                      { value: "#{styler.value originalTiming.repetitions}", space: SPACES_BY_COL[7] })

    for program in programs.others
        continue unless program.ensureExecutable()

        timing = program.time()

        continue unless timing.success

        isFasterThanOriginal = isFaster timing, originalTiming, confidenceRate
        cpuSpeedup = originalTiming.cpu/timing.cpu
        elpSpeedup = originalTiming.elapsed/timing.elapsed

        fasterString =
            if isFasterThanOriginal?
                if isFasterThanOriginal
                    styler.okay('FASTER')
                else
                    styler.bad('NOT FASTER')
            else
                styler.normal('UNKNOWN')

        logger.noTag compartimentedString({ value: chalk.bold(fasterString), space: SPACES_BY_COL[0], padKind: "Start" },
                                          { value: "#{prettySpeedup cpuSpeedup}", space: SPACES_BY_COL[1] },
                                          { value: "#{styler.value(toSecs(timing.cpu))}#{styler.unit 's'}", space: SPACES_BY_COL[2] },
                                          { value: "#{prettySpeedup elpSpeedup }", space: SPACES_BY_COL[3] }
                                          { value: "#{styler.value(toSecs(timing.elapsed))}#{styler.unit 's'}", space: SPACES_BY_COL[4] }
                                          { value: "#{styler.value(prettyDecimal(originalTiming.cpu_ratio, 2))}#{styler.unit '%'}", space: SPACES_BY_COL[5] }
                                          { value: "#{prettyMemory timing.mem_max}", space: SPACES_BY_COL[6] },
                                          { value: "#{styler.value timing.repetitions}", space: SPACES_BY_COL[7] })
