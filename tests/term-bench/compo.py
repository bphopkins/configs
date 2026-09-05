#!/usr/bin/env python3
"""Composition of a captured byte stream: compo.py CAPTURE

Use it to check that two captures are comparable before comparing the machines
or terminals that produced them. The 2026-09-05 fedxps/bigfed pair agreed within
0.5% on every column, which is what licensed the cross-machine comparison.
"""
import re, sys
d = open(sys.argv[1], 'rb').read()
c = lambda p: len(re.findall(p, d))
print("bytes %d  SGR %d  truecolor %d  sync %d  CUP %d" % (
    len(d), c(rb'\x1b\[[0-9;:]*m'), c(rb'38;2;'),
    c(rb'\x1b\[\?2026h'), c(rb'\x1b\[[0-9;]*H')))
