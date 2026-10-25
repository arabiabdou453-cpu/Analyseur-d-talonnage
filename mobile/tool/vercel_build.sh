#!/usr/bin/env bash
# Construit l'aperçu web de l'application Flutter sur Vercel.
# Sécurité : les tests (moteur, PDF, Excel, interface) passent AVANT toute
# publication ; un seul échec arrête le déploiement.
set -euo pipefail

FLUTTER_VERSION="3.47.8" # même version qu'en local
FLUTTER_DIR="$PWD/.flutter-sdk"

command -v unzip >/dev/null 2>&1 || dnf install -y unzip xz >/dev/null
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  git clone --depth 1 -b "$FLUTTER_VERSION" https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
flutter config --no-analytics >/dev/null
dart --disable-analytics >/dev/null 2>&1 || true
flutter --version

flutter pub get
flutter test
# CanvasKit servi par le site lui-même (pas de CDN tiers pour le moteur de rendu).
flutter build web --release --no-web-resources-cdn
