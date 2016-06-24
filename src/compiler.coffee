ProgramFamily = require './program-family'

@compile = (first, others = [], { last = no, literal = no } = {}) ->
    if literal
        programs = new ProgramFamily first, others, { shouldGuess: no }
    else
        indexFilter =
            if last
                [ { index: 0 }, { type: 'mt', index: -1 } ]

        programs = new ProgramFamily first, others, { indexFilter }

    do programs.compile
