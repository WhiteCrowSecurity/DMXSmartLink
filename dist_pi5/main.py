#!/usr/bin/env python3
"""DMXSmartLink launcher -- execs the Nuitka standalone binary."""
import os
import stat
import sys

_here = os.path.dirname(os.path.abspath(__file__))
_binary = os.path.join(_here, "main.dist", "main.bin")
try:
    _mode = os.stat(_binary).st_mode
    os.chmod(_binary, _mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
except OSError:
    pass
os.execv(_binary, [_binary] + sys.argv[1:])
