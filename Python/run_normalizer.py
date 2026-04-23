"""
run_normalizer.py
=================
Launcher for the Chameleon.

Usage:
    python run_normalizer.py

To package as a standalone executable (no Python needed on target machine):
    pip install pyinstaller
    pyinstaller --onefile --windowed --name "BatchStainNormalizer" run_normalizer.py

The resulting executable will be in the dist/ folder.
"""

import sys
import os

# Ensure the app directory is on the path when running from a different cwd
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from normalizer_app import main

if __name__ == '__main__':
    main()
