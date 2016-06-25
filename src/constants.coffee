# In this file you can find constants which require subjective configuration
# and or are used by more than one module

module.exports = @

# Profiling
@PROFILING_OUTPUT_FOLDER = "profiling"
@OPERF_EVENTS =
    cycles:
        event: 'CPU_CLK_UNHALTED'
        counter: 50000
    llc:
        event: 'LLC_MISSES'
        counter: 50000
    l2:
        event: 'LLC_REFS'
        counter: 50000
    l1:
        event: 'l2_rqsts'
        counter: 200000
    tlb:
        event: 'dtlb_load_misses'
        counter: 2000000
    branches:
        event: 'br_misp_retired'
        counter: 400000

# CLI constants
@SECOND_ALIAS_FOR_COMMANDS =
    spd: 'time'
    speedup: 'time'
    s: 'time'
    rm: 'clean'
    cln: 'clean'
    eq: 'equal'
    pf: 'profile'
    make: 'compile'

# Programs
@OPTIMIZED_PROGRAMS_INDICATOR_PATTERN = '-(opt|optim)'

# Logger
@MINIMUM_COLS_FOR_LINEBREAK = 15
@TAG_INDICATOR = ': '

# Timer
@DFL_REPETITIONS = 15
@DFL_TIME_LIMIT = 15

@CSV_OUTPUT_FOLDER = "csv"

# General
@DFL_DECIMAL_PLACES = 3

# Timer
@DFL_CONFIDENCE_RATE = 0.05

# Assembly
@ASSEMBLY_OUTPUT_FOLDER = "assembly"
