ProgramFamily = require './program-family'

@compile = (first, others = [], { single = no, last = no } = {}) ->
    if single
        programs = new ProgramFamily first, others, { shouldGuess: no }
    else
        indexFilter =
            if last
                [ { index: 0 }, { type: 'mt', index: -1 } ]

        programs = new ProgramFamily first, others, { indexFilter }

    do programs.compile
