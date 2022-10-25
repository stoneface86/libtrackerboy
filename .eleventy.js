
const { EleventyRenderPlugin } = require("@11ty/eleventy");
const pluginSeo = require('eleventy-plugin-seo');
const markdownIt = require("markdown-it");

module.exports = function(ec) {

  ec.addPlugin(EleventyRenderPlugin);
  ec.addPlugin(pluginSeo, require('./src/_data/seo.json'));

  {
    // GFM style with html enabled, indented code blocks disabled
    // Remove this when using eleventy 2.0
    var md = markdownIt('default', {
      html: true
    });
    md.disable('code');
    ec.setLibrary('md', md);
  }

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