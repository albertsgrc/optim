_ = require 'lodash'
assert = require 'assert'
{ quote } = require 'shell-quote'

module.exports = class ListString
    push = (how, elems...) ->
        for elem in elems
            if _.isArray elem
                push.apply @, [how].concat(elem)
            else if _.isString elem
                elem = _.trim elem, ' '
                continue if elem.length is 0
                how @, elem
            else if elem instanceof ListString
                how @, elem.array
            else
                assert(false,
                    "Option should be either a string, an array of strings or a ListString")

    constructor: (elems...) ->
        @array = []
        @pushBack elems...

    pushFront: _.partial push, (where, elem) ->
        if _.isArray elem
            where.array = elem.concat where.array
        else
            where.array.unshift elem

    pushBack: _.partial push, (where, elem) ->
        if _.isArray elem
            where.array = where.array.concat elem
        else
            where.array.push elem

    toString: -> quote @array
