"""
Lanceur universel TERRA-ORBIT TOGO
Compatible Python 3.10, 3.11, 3.12, 3.13, 3.14+
Résout automatiquement la gestion de l'event loop asyncio.
"""

import sys
import os
import asyncio

# Résolution proactive du changement asyncio sous Python 3.12 - 3.14+
try:
    loop = asyncio.get_event_loop()
except RuntimeError:
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

# Assure que le répertoire parent et courant sont dans le sys.path
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

from streamlit.web import cli as stcli

if __name__ == "__main__":
    app_path = os.path.join(current_dir, "app.py")
    sys.argv = ["streamlit", "run", app_path]
    sys.exit(stcli.main())
