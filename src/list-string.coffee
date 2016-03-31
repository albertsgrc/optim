_ = require 'lodash'
assert = require 'assert'

module.exports = class ListString
    string: ""

    push = (how, elems...) ->
        for elem in elems
            if _.isArray elem
                push how, elem...
            else if _.isString elem
                elem = _.trim elem, ' '
                continue if elem.length is 0
                if @string.length is 0
                    @string = elem
                else
                    @string = how(@string, elem)
            else
                assert(false,
                    "Option should be either a string or an array of strings")

    constructor: (elems...) -> @pushBack elems...

    pushFront: _.partial push, (string, elem) -> elem + " " + string

    pushBack: _.partial push, (string, elem) -> string + " " + elem

    toString: -> @string
