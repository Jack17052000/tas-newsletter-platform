#!/bin/bash
# Optimized launch script
export PATH="$PATH:$HOME/flutter/bin"
cd /mnt/d/Users/User/Desktop/tas-newsletter-platform/client_flutter

# We go back to debug mode for much faster startup
flutter run -d linux || read -p "Ocurrió un error. Presiona Enter para cerrar."
