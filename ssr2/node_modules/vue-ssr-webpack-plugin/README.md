# vue-ssr-webpack-plugin

A Webpack plugin for generating a server-rendering bundle that can be used with Vue 2.x's [bundleRenderer](https://github.com/vuejs/vue/tree/dev/packages/vue-server-renderer#why-use-bundlerenderer). **This plugin requires `vue-server-renderer@^2.2.0`**.

### Why?

When you use Webpack's on-demand code-splitting feature (via `require.ensure` or dynamic `import`), the resulting server-side bundle will contain multiple separate files. This plugin simplifies the workflow by automatically packing these files into a single JSON file that can be passed to `bundleRenderer`.

### Usage

``` bash
npm install vue-ssr-webpack-plugin --save-dev
```

``` js
// in your webpack server bundle config
const { VueSSRServerPlugin } = require('vue-ssr-webpack-plugin')

module.exports = {
  target: 'node',
  entry: '...',
  output: {
    path: '...',
    filename: '...',
    libraryTarget: 'commonjs2'
  },
  // ...
  plugins: [
    new VueSSRServerPlugin()
  ]
}
```

By default, the resulting bundle JSON will be generated as `vue-ssr-bundle.json` in your Webpack output directory. You can customize the filename by passing an option to the plugin:

``` js
new VueSSRPlugin({
  filename: 'my-bundle.json'
})
```

Using the generated bundle is straightforward:

``` js
const { createBundleRenderer } = require('vue-server-renderer')
const bundle = require('/path/to/my-bundle.json')
const renderer = createBundleRenderer(bundle) // can also directly pass the absolute path string.
```

**Note:** your server bundle should have single entry, so avoid using `CommonsChunkPlugin` in your server bundle config.

### Client Manifest

> Requires vue-server-renderer@^2.3 and vue-ssr-webpack-plugin@^2.0

`vue-server-renderer` 2.2 supports rendering the entire HTML page with the `template` option. 2.3 introduces another new feature, which allows us to pass a manifest of our client-side build to the `bundleRenderer`. This provides the renderer with information of both the server AND client builds, so it can automatically infer and inject preload/prefetch directives and script tags into the rendered HTML. This is particularly useful when rendering a bundle that leverages webpack's on-demand code splitting features: we can ensure the right chunks are preloaded/prefetched, and also directly embed `<script>` tags for needed async chunks in the HTML to avoid waterfall requests on the client, thus improving TTI (time-to-interactive).

To generate a client manifest, you need to add the client plugin to your client webpack config. In addition:

- Make sure to use `CommonsChunkPlugin` to split the webpack runtime into its own entry chunk, so that async chunks can be injected **after** the runtime and **before** your main app code.

- Since in this case `vue-server-renderer` will be dynamically injecting the asset links, you don't need to use `html-webpack-plugin`. However, the setup only handles JavaScript. If you want to use `html-webpack-plugin` for embedding other types of assets (e.g fonts), you can still use it - just make sure to configure it with `inject: false` so that it doesn't duplicate-inject the scripts.

``` js
// in your webpack client bundle config
const webpack = require('webpack')
const { VueSSRClientPlugin } = require('vue-ssr-webpack-plugin')

module.exports = {
  // ...
  plugins: [
    // this splits the webpack runtime into a leading chunk
    // so that async chunks can be injected right after it.
    // this also enables better caching for your app/vendor code.
    new webpack.optimize.CommonsChunkPlugin({
      name: 'manifest',
      minChunks: Infinity
    }),
    // this will generate the client manifest JSON file.
    new VueSSRClientPlugin()
  ]
}
```

This will generate an additional `vue-ssr-client-manifest.json` file in your build output. Simply require and pass it to the `bundleRenderer`:

``` js
const { createBundleRenderer } = require('vue-server-renderer')

const template = require('fs').readFileSync('/path/to/template.html', 'utf-8')
const serverBundle = require('/path/to/vue-ssr-bundle.json')
const clientManifest = require('/path/to/vue-ssr-client-manifest.json')

const renderer = createBundleRenderer(serverBundle, {
  template,
  clientManifest
})
```

With this setup, your server-rendered HTML for a build with code-splitting will look something like this:

``` html
<html><head>
  <!-- chunks used for this render should have preload -->
  <link rel="preload" href="/manifest.js" as="script">
  <link rel="preload" href="/main.js" as="script">
  <link rel="preload" href="/0.js" as="script">
  <!-- unused async chunks should have prefetch -->
  <link rel="prefetch" href="/1.js" as="script">
</head><body>
  <div data-server-rendered="true"><div>async</div></div>
  <!-- manifest chunk should be first -->
  <script src="/manifest.js"></script>
  <!-- async chunks should be before main chunk -->
  <script src="/0.js"></script>
  <script src="/main.js"></script>
</body></html>`
```

Note the renderer by default only generates preload links for JavaScript assets. You can apply fine-grained control on what to add preload links for using the `shouldPreload` option:

``` js
const renderer = createBundleRenderer(serverBundle, {
  template,
  clientManifest,
  shouldPreload: (file, type) => {
    // type is inferred based on the file extension.
    // https://fetch.spec.whatwg.org/#concept-request-destination
    if (type === 'script') {
      return true
    }
    if (type === 'font') {
      // only preload woff2 fonts
      return /\.woff2$/.test(file)
    }
    if (type === 'image') {
      // only preload important images
      return file === 'hero.jpg'
    }
  }
})
```
