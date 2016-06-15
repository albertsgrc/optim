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
{ profile, addProfilingOption } = require './profiler'
{ SECOND_ALIAS_FOR_COMMANDS } = require './constants'
Program = require './program'

######### - Argument checks and preprocess - ##########
N_META_ARGUMENTS = 2
COMMANDS = [
    'time', 't',
    'clean', 'C',
    'equal', 'e',
    'compile', 'c',
    'profile', 'p'
]

cli.notEnoughArguments = process.argv.length <= N_META_ARGUMENTS

# Replace the command argument if it is a second alias defined for convenience
# (Commander only allows one alias per command)
tryToReplaceSecondAlias = ->

    realCommand = SECOND_ALIAS_FOR_COMMANDS[process.argv[N_META_ARGUMENTS]]
    process.argv[N_META_ARGUMENTS] = realCommand if realCommand?

checkCommandExists = ->
    cmd = process.argv[N_META_ARGUMENTS]
    unless cmd in COMMANDS or cmd[0] is '-'
        logger.e("#{styler.id cmd} is not a optim command. Run #{styler.id 'optim --help'}
                  for the list of commands", margin: on, exit: yes, printStack: no)

######### - CLI command, options and version definitions- ##########
cli.version version

# TODO: Features for PCA Project:
# - Configuration file with default options
# - Compilation via Makefiles
# - Hability to define tasks, wich group commands
# - Profiling
# - Custom equality check

# Subcommand-independent options
cli
    .option '-v, --verbose', "Show verbose output"

# TODO: Add option to ignore certain exit codes when program crashes

# Equal command

cli
    .command 'equal <original-program> [others...]'
    .alias 'e'
    .description 'Check equality of stdout output to verify correctness'
    .option '-a, --forward-args <[program-specification:]arguments-string>',
        "Forward arguments to the programs", Program.addArguments
    .option '-A, --all',
        "Check equality for all programs. Otherwise check only for the program with latest modification time"
    .option '-i, --input-file [program-specification:]<file>',
        "Specify file that will serve as input for the execution of the programs",
        Program.addInputFile
    .option '-s, --input-string [program-specification:]<string>',
        "Specify string that will serve as input for the execution of the programs",
        Program.addInputString
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
    .option '-l, --last', 'Only compile the original and lastly modified programs'
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
    .option '-A, --all',
        "Compute info for all the programs. Otherwise compute for the two with greatest modification time"
    .option '-F, --first', "Compute speedup only with the original program. Ignored if --all is specified."
    # TODO: Add option to compare speedup within last two
    .option '-i, --input-file [program-specification:]<file>',
        "Specify file that will serve as input for the execution of the programs", Program.addInputFile
    .option '-s, --input-string [program-specification:]<string>',
        "Specify string that will serve as input for the execution of the programs", Program.addInputString
    .option '-o, --output-file [program-specification:]<file>',
        "Specify file that will serve as output for the execution of the programs.
         If not specified output is ignored", Program.addOutputFile
    .action time

# Profile command
cli
    .command 'profile <program> [others...]'
    .alias 'p'
    .description 'Profile the given programs'
    .option '-A, --all',
        "Profile all programs. Otherwise profile only the program with latest modification time"
    .option '-e, --event [event]', "Event which is going to be profiled", /^(cycles|branches|llc|l2|l1)$/i, 'cycles'
    .option '-S, --assembly',
        "Annotate assembly code instead of C code"
    .option '-f, --forward-options [program-specification:]<options>',
        "Forward options to the profiler (operf or gprof)", addProfilingOption
    .option '-g, --gprof', "Profile with gprof"
    .option '-n, --no-clean', "Do not clean profiler's intermediate files"
    .option '-a, --forward-args <[program-specification:]arguments-string>',
        "Forward arguments to the programs", Program.addArguments
    .option '-i, --input-file [program-specification:]<file>',
        "Specify file that will serve as input for the execution of the programs", Program.addInputFile
    .option '-s, --input-string [program-specification:]<string>',
        "Specify string that will serve as input for the execution of the programs", Program.addInputString
    .option '-o, --output-file [program-specification:]<file>',
        "Specify file that will serve as output for the execution of the programs.
         If not specified output is ignored", Program.addOutputFile
    .option '-S, --save [filename]'
    .action profile

# Assembly command
# TODO

# Clean command
cli
    .command 'clean'
    .alias 'C'
    .description "Remove all executables in the directory"
    .option '-r, --recursive', "Recursively delete executables on all directories"
    .option '-d, --deep', "Also remove oprofile output and all files ending in .out"
    .option '-u, --ultra-deep', "Also remove generated profiling result files"
    .action clean

do cli.help if cli.notEnoughArguments
do tryToReplaceSecondAlias
do checkCommandExists

cli.parse process.argv
