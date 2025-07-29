// Original script would miss these variations:
const config = {
    // Standard format (original script handles this)
    basePath: "__administration__/",
    
    // Unicode escaped (MISSED by original script)
    apiEndpoint: "__administration__\u002Fapi/users",
    resourcePath: "__administration__\u002F",
    
    // URL encoded (MISSED by original script) 
    redirectUrl: "__administration__%2Fdashboard",
    
    // JSON escaped slashes (MISSED by original script)
    staticAssets: "__administration__\/css/",
    deepEscaped: "__administration__\\\/js/",
    
    // Quoted variations (MISSED by original script)
    routes: {
        "__administration__/": "/new-admin/",
        '__administration__/users': '/new-admin/users'
    }
};