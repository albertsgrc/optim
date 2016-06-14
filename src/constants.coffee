# In this file you can find constants which require subjective configuration
# and or are used by more than one module

module.exports = @

# Profiling
@PROFILING_OUTPUT_FOLDER = "profiling"

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

# General
@DFL_DECIMAL_PLACES = 3

# Timer
@DFL_CONFIDENCE_RATE = 0.05
