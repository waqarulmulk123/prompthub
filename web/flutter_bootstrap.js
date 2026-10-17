{{flutter_js}}
{{flutter_build_config}}
for (const build of _flutter.buildConfig.builds) {
  if (build.jsSupportRuntimePath) {
    build.jsSupportRuntimePath += '?v=' + _flutter.buildConfig.wasmHashes[build.mainWasmPath];
  }
}
_flutter.loader.load();
