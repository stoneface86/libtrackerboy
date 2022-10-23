
const { EleventyRenderPlugin } = require("@11ty/eleventy");
const pluginSeo = require('eleventy-plugin-seo');

module.exports = function(ec) {

  ec.addPlugin(EleventyRenderPlugin);
  ec.addPlugin(pluginSeo, require('./src/_data/seo.json'));

  ec.setBrowserSyncConfig({
    files: [
      './_site/css/style.css'
    ]
  });

  ec.addPassthroughCopy('src/assets');
  ec.addPassthroughCopy('src/docs');
  
  ec.addFilter("docsLink", function(input) {
    return `/docs/${ input }/libtrackerboy.html`;
  });
  ec.addFilter("srcLink", function(input) {
    return `https://github.com/stoneface86/libtrackerboy/tree/${ input }`;
  });

  return {
    dir: {
      input: 'src',
      output: '_site',
    },
    pathPrefix: '/libtrackerboy/'
  };

};