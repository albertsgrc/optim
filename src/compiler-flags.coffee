module.exports = FLAGS =
    oF: ['-Ofast', '-march=native']
    oS: '-Os'
    o3: ['-O3', '-march=native']
    o2: '-O2'
    o1: '-O1'
    o0: '-O0'

    g: '-g'
    pg: '-pg'
    s: '-static'
    ni: '-fno-inline'

    pca: ['-O3', '-march=native', '-mfpmath=sse', '-ffloat-store', '-Wl,-s,-O1', '-lm']

ALIAS =
    0: 'o0'
    1: 'o1'
    2: 'o2'
    3: 'o3'
    f: 'oF'

    noinline: 'ni'
    ninline: 'ni'

    static: 's'
    st: 's'

FLAGS[alias] = FLAGS[flag] for alias, flag of ALIAS
