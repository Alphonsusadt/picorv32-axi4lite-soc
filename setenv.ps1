# Setup environment OSS CAD Suite untuk PowerShell (padanan setenv.bat).
# Jalankan dengan dot-sourcing agar variabel tetap berlaku di sesi ini:
#   . .\setenv.ps1

$root = "D:\tools\oss-cad-suite\"
if (-not $env:YOSYSHQ_ROOT) { $env:YOSYSHQ_ROOT = $root }
$root = $env:YOSYSHQ_ROOT

$env:SSL_CERT_FILE          = "${root}etc\cacert.pem"
$env:PATH                   = "${root}bin;${root}lib;$env:PATH"
$env:PYTHON_EXECUTABLE      = "${root}lib\python3.exe"
$env:QT_PLUGIN_PATH         = "${root}lib\qt6\plugins"
$env:QT_LOGGING_RULES       = "*=false"
$env:GTK_EXE_PREFIX         = $root
$env:GTK_DATA_PREFIX        = $root
$env:GDK_PIXBUF_MODULEDIR   = "${root}lib\gdk-pixbuf-2.0\2.10.0\loaders"
$env:GDK_PIXBUF_MODULE_FILE = "${root}lib\gdk-pixbuf-2.0\2.10.0\loaders.cache"
$env:OPENFPGALOADER_SOJ_DIR = "${root}share\openFPGALoader"

& "${root}lib\gdk-pixbuf-query-loaders.exe" --update-cache

function global:prompt { "[OSS CAD Suite] PS $(Get-Location)> " }
