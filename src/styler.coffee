chalk = require 'chalk256'
assert = require 'assert'

{ TERM } = process.env
supports256 = TERM? and /^xterm-256(?:color)?/.test(TERM)

styles256 =
    error: chalk("#e74c3c")
    warning: chalk("#f39c12")
    info: chalk("#3498db")

    cmd: chalk("#95a5a6").bold.underline
    id: chalk("#95a5a6").italic.bold
    value: chalk.bold

    okay: chalk("#2ecc71")
    normal: chalk("#f1c40f")
    bad: chalk("#9b59b6")

styles16 =
    error: chalk.red
    warning: chalk.yellow
    info: chalk.blue

    cmd: chalk.white.underline
    id: chalk.cyan.italic.bold
    value: chalk.bold

    okay: chalk.green
    normal: chalk.white
    bad: chalk.yellow

# SANITY-CHECKS
assert(Object.keys(styles256).length is Object.keys(styles16).length,
       "256 and 16 styles don't have the same properties")
assert(prop of styles256, "Style #{prop} missing in 256") for prop of styles16

module.exports = if supports256 then styles256 else styles16
