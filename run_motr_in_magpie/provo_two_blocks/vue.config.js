module.exports = {
  configureWebpack: {
    module: {
      rules: [
        {
          test: /\.(csv|tsv)$/,
          loader: 'csv-loader',
          options: {
            dynamicTyping: true,
            header: true,
            skipEmptyLines: true,
            delimiter: '\t'
          }
        }
      ]
    }
  },
  lintOnSave: false,
  pluginOptions: {
    lintStyleOnBuild: false,
    stylelint: {}
  },
  publicPath: process.env.NODE_ENV === 'production' ? './' : '/'
};

