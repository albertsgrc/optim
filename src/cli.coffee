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
{ profile, addProfilingOption, OPERF_EVENTS_REGEX } = require './profiler'
{ assembly } = require './assembly'
{ SECOND_ALIAS_FOR_COMMANDS, PROFILING_OUTPUT_FOLDER, OPERF_EVENTS, ASSEMBLY_OUTPUT_FOLDER } = require './constants'
Program = require './program'

######### - Argument checks and preprocess - ##########
N_META_ARGUMENTS = 2
COMMANDS = [
    'time', 't',
    'clean', 'C',
    'equal', 'e',
    'compile', 'c',
    'profile', 'p',
    'assembly', 'a'
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

# TODO: Optional features for PCA Project:
# - Configuration file with default options
# - Compilation via Makefiles
# - Hability to define tasks, wich group commands

# Subcommand-independent options
cli
    .option '-v, --verbose', "Show verbose output"

# TODO: Add option to ignore certain exit codes when program crashes

# Equal command

cli
    .command 'equal <original-program> [others...]'
    .alias 'e'
    .description 'Check equality of stdout output to verify correctness'
    .option '-a, --forward-args [program-specification:]<arguments-string>',
        "Forward arguments to the programs", Program.addArguments
    .option '-A, --all',
        "Check equality for all programs. Otherwise check only for the program with latest modification time"
    .option '-i, --input-file [program-specification:]<file>',
        "Specify file that will serve as input for the execution of the programs",
        Program.addInputFile
    .option '-s, --input-string [program-specification:]<string>',
        "Specify string that will serve as input for the execution of the programs",
        Program.addInputString
    .option '-c, --custom <equality-checker-js-file>', "Specify a custom equality checker. Should export an eq method which receives two strings."
    .action check

# Compile command
# TODO: More complex compilation support with Makefiles and local/global configuration files
cli
    .command 'compile <program> [others...]'
    .alias 'c'
    .description "Compile the given programs"
    .option '-f, --flags [program-specification:]<flags-string>',
        "Indicate flags to forward to the compilation of programs", Program.addFlags
    .option '-L, --literal', 'Only compile the given program. Otherwise, similar
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
        "Confidence rate for the T-Student test."
    .option '-p, --previous',
        "Compute speedup with respect to the previous program"
    .option '-H, --set-high-priority', "Sets the program executions to high priority so that the OS doesn't switch them."
    .option '-I, --instrumented', "Timing is gathered from program's stderr output. Should mimic \"timer -ni\" cmd output format."
    .option '-a, --forward-args [program-specification:]<arguments-string>',
        "Forward arguments to the programs", Program.addArguments
    .option '-A, --all',
        "Compute info for all the programs. Otherwise compute for the two with greatest modification time"
    .option '-F, --first', "Compute speedup only with the original program. Ignored if --all is specified."
    .option '-i, --input-file [program-specification:]<file>',
        "Specify file that will serve as input for the execution of the programs", Program.addInputFile
    .option '-s, --input-string [program-specification:]<string>',
        "Specify string that will serve as input for the execution of the programs", Program.addInputString
    .option '-o, --output-file [program-specification:]<file>',
        "Specify file that will serve as output for the execution of the programs.
         If not specified output is ignored", Program.addOutputFile
    .option '-C, --csv [file]', "Output a CSV file with the data."
    .action time

# Profile command
cli
    .command 'profile <program> [others...]'
    .alias 'p'
    .description 'Profile the given programs'
    .option '-L, --literal', "Profile only the given program"
    .option '-A, --all',
        "Profile all programs. Otherwise profile only the program with latest modification time"
    .option '-e, --event [event]',
        "Event which is going to be profiled. One of: #{(key for key of OPERF_EVENTS).join(', ')}",
        OPERF_EVENTS_REGEX,
        'cycles'
    .option '-c, --counter [counter]', "Specify event counter value"
    .option '-S, --assembly',
        "Annotate assembly code instead of C code"
    .option '-F, --save-file [filename]',
        "Save output to file inside #{PROFILING_OUTPUT_FOLDER} folder"
    .option '-g, --gprof', "Profile with gprof"
    .option '-n, --no-clean', "Do not clean profiler's intermediate files"
    .option '-f, --forward-options [program-specification:]<options>',
        "Forward options to the profiler (operf or gprof)", addProfilingOption
    .option '-a, --forward-args [program-specification:]<arguments-string>',
        "Forward arguments to the programs", Program.addArguments
    .option '-i, --input-file [program-specification:]<file>',
        "Specify file that will serve as input for the execution of the programs", Program.addInputFile
    .option '-s, --input-string [program-specification:]<string>',
        "Specify string that will serve as input for the execution of the programs", Program.addInputString
    .option '-o, --output-file [program-specification:]<file>',
        "Specify file that will serve as output for the execution of the programs.
         If not specified output is ignored", Program.addOutputFile
    .action profile

# Assembly command
cli
    .command 'assembly <program> [others...]'
    .alias 'a'
    .description 'Output assembly code of an executable'
    .option '-L, --literal', "Profile only the given program"
    .option '-p, --pretty', "Interleave assembly with the corresponding lines of code"
    .option '-A, --all',
        "Output assembly of all programs. Otherwise only of the program with latest modification time"
    .option '-F, --save-file [filename]',
        "Save output to file inside #{ASSEMBLY_OUTPUT_FOLDER} folder"
    .action assembly

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
