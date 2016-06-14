{ attemptShell, isBinaryExecutable } = require './utils'
logger = require './logger'
styler = require './styler'
{ PROFILING_OUTPUT_FOLDER } = require './constants'
_ = require 'lodash'

@clean = ({ recursive = no, ultraDeep = no, deep = ultraDeep, } = {}) ->
    hasFileTool = attemptShell('which', 'file')?

    unless hasFileTool
        if process.platform is "win32"
            logger.e "Tool #{styler.id 'file'} is required for this command.
                      You can download it from the following link:
                      http://gnuwin32.sourceforge.net/packages/file.htm", { exit: yes, printStack: no }
        else
            logger.e "Tool #{styler.id 'file'} is required for this command.
               Make sure it is installed and it is in your PATH variable"

    filter =
        if deep
            (file) ->
                isBinaryExecutable(file) or
                file.match(/\.out$/) or
                file.match(/oprofile_data/) or
                (ultraDeep and (
                    file is PROFILING_OUTPUT_FOLDER
                ))
        else
            isBinaryExecutable

    if recursive
        files = _.filter attemptShell('ls', ['-R', '.']), filter
    else
        files = _.filter attemptShell('ls', '.'), filter

    if files.length > 0
        logger.i "Removing #{files.join(", ")}"
        attemptShell('rm', ['-R', files])
    else
        logger.i "No files found to remove"
