var webpack = require("webpack");
var ExtractTextPlugin = require("extract-text-webpack-plugin");
module.exports = {
  entry: './src/webpack-entry.js',
  output: {
    filename: 'public/bundle.js',
    path: __dirname
  },
  module: {
    loaders: [
      { test: /\.coffee$/, loader: "coffee" },
      { test: /\.jade$/, loader: "jade-loader" },
      {
        test: /\.css$/,
        loader: ExtractTextPlugin.extract("css-loader")
      },
      { test: /\.png$/, loader: "file-loader" }
    ]
  },
  resolve: {
    extensions: ["", ".web.coffee", ".web.js", ".coffee", ".js"]
  },
  plugins: [
    new ExtractTextPlugin("public/bundle.css", { allChunks: true })
    /*, new webpack.optimize.UglifyJsPlugin({
      mangle: {
        except: ['$', 'exports', 'require']
      }
    })/**/
  ]
};
