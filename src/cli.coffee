#! /usr/bin/env coffee

cli = require 'commander'

# Get version number from package.json to avoid redundancy
{ version } = require '../package'

module.exports = cli

######### - Argument checks and preprocess - ##########
cli.notEnoughArguments = process.argv.length <= 2

######### - CLI command, options and version definitions- ##########
cli.version version

# Subcommand-independent options
cli
    .option '-v, --verbose', "Show verbose output"

# Equal command
cli
    .command 'equal <original-program> [others...]'
    .alias 'e'
    .description 'Check equality of stdout output to verify correctness'
    .option '-a, --forward-args <[program-specification:]arguments-string>',
        "Forward arguments to the programs"
    .option '-l, --last',
        "Only check equality with the program with greatest lexicographic name"
    .action -> console.log "Equal"

# Compile command
cli
    .command 'compile <program> [others...]'
    .alias 'c'
    .description "Compile the given programs"
    .option '-f, --flags [program-specification:]<flags-string>',
        "Indicate flags to forward to the compilation of programs"
    .option '-a, --all', 'Compile all matching programs in lexicographic order'
    .action -> console.log "Compile"

# Speedup command
cli
    .command 'speedup <original-program> [others...]'
    .alias 's'
    .description "Compute speedups, execution times and t-student test"
    .option '-r, --repetitions <repetitions>',
        "Maximum program executions to average speedup for each of them."
    .option '-f, --force-steps',
        "Force to execute all steps independently of time limit"
    .option '-t, --time-limit <time_in_seconds>',
        "Time limit for all repetitions of a single program time check."
    .option '-c, --confidence-rate <rate>',
        "Confidence rate for the T-Student test"
    .option '-a, --forward-args [program-specification:]<arguments-string>',
        "Forward arguments to the programs"
    .option '-l, --last',
        "Only compute info for the program with greatest lexicographic name"
    .action -> console.log "Speedup"

# Profile command
cli
    .command 'profile <program> [others...]'
    .alias 'p'
    .description 'Profile the given programs'
    .option '-o, --o-profile [:options-string]',
        "Profile with OProfile's opannotate"
    .option '-g, --gprof [:options-string]', "Profile with gprof"
    .option '-n, --no-clean', "Do not clean profiler's intermediate files"
    .action -> console.log "Profile"

# TODO: Analyze = Speedup + Profile command
# TODO: All = Check + Speedup + Profile command

# Clean command
cli
    .command 'clean'
    .alias 'C'
    .description "Remove all executables in the directory"
    .action -> console.log "Clean"

cli.help() if cli.notEnoughArguments
cli.parse process.argv
