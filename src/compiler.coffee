ProgramFamily = require './program-family'

@compile = (first, others = [], { single = no, last = no } = {}) ->
    if single
        programs = new ProgramFamily first, others, { shouldGuess: no }
    else
        programs = new ProgramFamily first, others

        if last and programs.all.length > 1
            programs.all = [programs.allSortedByMt[0], programs.allSortedByMt[-1..][0]]

    do programs.compile
