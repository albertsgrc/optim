ProgramFamily = require './program-family'

@compile = (first, others = [], { single = no } = {}) ->
    if single
        programs = new ProgramFamily(first, others, { shouldGuess: no })
        programs.compile()
    else
        for program in [first].concat(others)
            programs = new ProgramFamily(program)
            programs.compile()
