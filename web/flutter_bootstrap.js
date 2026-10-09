{{flutter_js}}
{{flutter_build_config}}

// Use the engine shipped by Flutter's dev server / build output, not a CDN.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: new URL('canvaskit/', document.baseURI).toString(),
  },
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
    } catch (error) {
      window.showBootError();
      console.error('Flutter initialization failed', error);
    }
  },
}).catch(function(error) {
  window.showBootError();
  console.error('Flutter loader failed', error);
});
