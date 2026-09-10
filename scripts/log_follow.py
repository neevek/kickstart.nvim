"""Follow a log file across append, truncation and rotation; start with its last 128 KiB."""
import os
import sys
import time

path = sys.argv[1]
identity = None
position = 0
first = True
while True:
    try:
        with open(path, 'rb') as source:
            stat = os.fstat(source.fileno())
            key = (stat.st_dev, stat.st_ino)
            if identity != key or stat.st_size < position:
                position = max(0, stat.st_size - 131072) if first else 0
                identity = key
                source.seek(position)
                if position:
                    source.readline()
                    position = source.tell()
                first = False
            source.seek(position)
            data = source.read(65536)
            position = source.tell()
            if data:
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
    except FileNotFoundError:
        pass
    time.sleep(0.1)
