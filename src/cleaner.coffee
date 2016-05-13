{ attemptShell, isBinaryExecutable } = require './utils'
logger = require './logger'
styler = require './styler'
_ = require 'lodash'

@clean = ({ recursive = no, deep = no } = {}) ->
    hasFileTool = attemptShell('which', 'file')?

    unless hasFileTool
        if process.platform is "win32"
            logger.e "Tool #{styler.id 'file'} is required for this command.
                      You can download it from the following link:
                      http://gnuwin32.sourceforge.net/packages/file.htm"
        else
            logger.e "Tool #{styler.id 'file'} is required for this command.
               Make sure it is installed and it is in your PATH variable"

    filter =
        if deep
            (file) ->
                isBinaryExecutable(file) or
                file.match(/\.out$/) or
                file.match(/oprofile_data/)
        else
            isBinaryExecutable

    if recursive
        files = _.filter attemptShell('ls', ['-R', '.']), filter
    else
        files = _.filter attemptShell('ls', '.'), filter

    if files.length > 0
        logger.i "Removing #{files.join(", ")}"
    else
        logger.i "No files found to remove"

    attemptShell('rm', ['-R', files])
