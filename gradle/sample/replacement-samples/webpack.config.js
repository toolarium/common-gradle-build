module.exports = {
    // Standard (original handles)
    publicPath: '__administration__/',
    
    // Escaped for build tools (original misses) 
    output: {
        path: path.resolve(__dirname, '__administration__\/dist'),
        publicPath: '__administration__\u002F'
    },
    
    // Template replacements
    plugins: [
        new HtmlWebpackPlugin({
            template: '__administration__/index.html',
            templateParameters: {
                basePath: '__administration__\u002F',
                apiUrl: '__administration__%2Fapi'
            }
        })
    ]
};