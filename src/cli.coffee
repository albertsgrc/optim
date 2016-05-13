#! /usr/bin/env coffee

module.exports = global.cli = cli = require 'commander'

# Get version number from package.json to avoid redundancy
{ version } = require '../package'
logger = require './logger'
styler = require './styler'
{ clean } = require './cleaner'
{ check } = require './equality-checker'
{ compile } = require './compiler'
{ time } = require './timer'
Program = require './program'

######### - Argument checks and preprocess - ##########
N_META_ARGUMENTS = 2

cli.notEnoughArguments = process.argv.length <= N_META_ARGUMENTS

# Replace the command argument if it is a second alias defined for convenience
# (Commander only allows one alias per command)
tryToReplaceSecondAlias = ->
    SECOND_ALIAS =
        spd: 'time', speedup: 'time', s: 'time', rm: 'clean', cln: 'clean', eq: 'equal', pf: 'profile'
        make: 'compile'

    realCommand = SECOND_ALIAS[process.argv[N_META_ARGUMENTS]]
    process.argv[N_META_ARGUMENTS] = realCommand if realCommand?

checkCommandExists = ->
    COMMANDS = ['time', 't', 'clean', 'C', 'equal', 'e', 'compile', 'c',
                'profile', 'p']

    cmd = process.argv[N_META_ARGUMENTS]
    unless cmd in COMMANDS or cmd[0] is '-'
        logger.e("#{styler.id cmd} is not a optim command. Run #{styler.id 'optim --help'}
                  for the list of commands", margin: on, exit: yes, printStack: no)

######### - CLI command, options and version definitions- ##########
cli.version version

# Subcommand-independent options
cli
    .option '-v, --verbose', "Show verbose output"

# Equal command
# TODO: Should add support for specifying input/output files
cli
    .command 'equal <original-program> [others...]'
    .alias 'e'
    .description 'Check equality of stdout output to verify correctness'
    .option '-a, --forward-args <[program-specification:]arguments-string>',
        "Forward arguments to the programs", Program.addArguments
    .option '-l, --last',
        "Only check equality with the program with latest modification time"
    .action check

# Compile command
# TODO: More complex compilation support with Makefiles and local/global configuration files
cli
    .command 'compile <program> [others...]'
    .alias 'c'
    .description "Compile the given programs"
    .option '-f, --flags [program-specification:]<flags-string>',
        "Indicate flags to forward to the compilation of programs", Program.addFlags
    .option '-s, --single', 'Only compile the given program. Otherwise, similar
                             programs are searched and compiled in lexicographic order'
    .action compile

# Speedup command
# TODO: Automatic latex graph generation
cli
    .command 'time <original-program> [others...]'
    .alias 't'
    .description "Compute speedups, execution times and t-student test"
    .option '-r, --repetitions <repetitions>',
        "Maximum program executions to average speedup for each of them."
    .option '-f, --force-repetitions',
        "Force to execute all repetitions independently of time limit"
    .option '-t, --time-limit <time_in_seconds>',
        "Time limit for all repetitions of a single program time check."
    .option '-c, --confidence-rate <rate>',
        "Confidence rate for the T-Student test"
    .option '-a, --forward-args [program-specification:]<arguments-string>',
        "Forward arguments to the programs", Program.addArguments
    .option '-l, --last',
        "Only compute info for the program with latest modification time"
    .action time

# Profile command
cli
    .command 'profile <program> [others...]'
    .alias 'p'
    .description 'Profile the given programs'
    .option '-o, --o-profile [:options-string]',
        "Profile with OProfile's opannotate"
    .option '-g, --gprof [:options-string]', "Profile with gprof"
    .option '-n, --no-clean', "Do not clean profiler's intermediate files"
    .action -> console.log "Profile" # TODO: Implement

# TODO: Analyze = Speedup + Profile command
# TODO: All = Check + Speedup + Profile command

# Clean command
cli
    .command 'clean'
    .alias 'C'
    .description "Remove all executables in the directory"
    .option '-r, --recursive', "Recursively delete executables on all directories"
    .option '-d, --deep', "Also remove oprofile output and all files ending in .out"
    .action clean

# TODO: Macro creation command

cli.help() if cli.notEnoughArguments
tryToReplaceSecondAlias()
checkCommandExists()

cli.parse process.argv
