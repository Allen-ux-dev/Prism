#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAIN="$ROOT/Packages/PrismCore/Sources/prismd/main.swift"
RUNTIME="$ROOT/Packages/PrismCore/Sources/PrismDaemonCore/RuntimeApplicationServices.swift"
ADAPTERS="$ROOT/Packages/PrismCore/Sources/PrismDaemonCore/ApplicationCompatibilityAdapters.swift"
CAPS="$ROOT/Packages/PrismCore/Sources/PrismDomain/CapabilityModels.swift"

fail() { echo "Application runtime wiring gate failed: $1" >&2; exit 1; }

rg -q 'ApplicationRuntimeProviderResolver' "$MAIN" || fail "prismd does not resolve runtime application providers"
rg -q 'resolveProviderSet' "$MAIN" || fail "prismd does not resolve the provider set"
if rg -q 'let applicationProvider\s*=\s*UnavailableApplicationExecutionProvider\(\)' "$MAIN"; then
  fail "prismd still hardcodes unavailable application provider as primary wiring"
fi
if rg -q 'let injectionProvider\s*=\s*UnavailableInjectionExecutionProvider\(\)' "$MAIN"; then
  fail "prismd still hardcodes unavailable injection provider as primary wiring"
fi

for token in 'Process\(' 'NSTask' 'posix_spawn' 'system\(' '/bin/sh' '/bin/bash'; do
  if rg -q "$token" "$RUNTIME" "$ADAPTERS"; then
    fail "runtime application adapter exposes prohibited raw execution surface: $token"
  fi
done

for cap in app-install app-registration app-replace app-removal app-refresh app-injection dylib-injection framework-injection bundle-injection; do
  rg -q "dev\.prism\.capability\.$cap" "$CAPS" || fail "missing capability identifier: $cap"
done

if rg -n -i 'trollstore|trollfools' "$ROOT/App" >/tmp/prism-app-product-copy.txt; then
  cat /tmp/prism-app-product-copy.txt >&2
  fail "product-specific compatibility names leaked into App UI/application behavior"
fi

echo "Prism application runtime wiring contract OK."
