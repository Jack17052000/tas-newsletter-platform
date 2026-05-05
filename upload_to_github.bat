@echo off
echo ========================================================
echo   Subiendo actualizaciones de codigo fuente a GitHub...
echo   Repositorio: Jack17052000/tas-newsletter-platform
echo ========================================================
echo.

:: 1. Agrega todos los archivos modificados
git add .

:: 2. Aseguramos el paquete de actualizacion
git commit -m "Completado motor PDF offline A5 con interfaz Live Layout y soporte de imagenes dinámicas estilo Broadsheet"

:: 3. Lo sube agresivamente a tu nube
git push

echo.
echo ========================================================
echo   ¡Proceso finalizado! 
echo   Si la consola no marco error, tus archivos estan a salvo en la nube.
echo ========================================================
pause
