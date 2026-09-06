#!/usr/bin/env python3
"""Never locks: records the watcher command and waits for lifecycle shutdown."""
import json
import os
import signal
import sys

with open(os.environ['IDLE_TEST_ARGS'], 'w') as output:
    json.dump(sys.argv[1:], output)
signal.pause()
