ProgramFamily = require './program-family'

module.exports = @

@profile = (original, others, {
                                event = 'cycles'
                                assembly = no
                                gprof = no
                                noClean = no
                                save = no
                                all = no
                              }) ->
    programs = new ProgramFamily original, others
