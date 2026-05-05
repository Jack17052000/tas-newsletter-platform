#!/bin/bash
# Optimized launch script
export PATH="$PATH:$HOME/flutter/bin"

# Auto-instalar zenity para el panel de imágenes si falta
if ! command -v zenity &> /dev/null
then
    echo "Instalando dependencia gráfica (zenity)... Puede pedir tu contraseña de ubuntu."
    sudo apt-get update && sudo apt-get install -y zenity
fi

# Crear puentes (symlinks) a Windows para que el File Picker de Linux encuentre las imágenes fácilmente
if [ ! -L "$HOME/Escritorio_Windows" ]; then
    echo "Creando puentes de acceso directo entre Windows y Linux..."
    ln -s /mnt/d/Users/User/Desktop "$HOME/Escritorio_Windows"
    ln -s /mnt/d/Users/User "$HOME/Archivos_Windows_D"
    ln -sf /mnt/c/Users/User "$HOME/Archivos_Windows_C"
fi

cd /mnt/d/Users/User/Desktop/tas-newsletter-platform/client_flutter

# We go back to debug mode for much faster startup
flutter run -d linux || read -p "Ocurrió un error. Presiona Enter para cerrar."
