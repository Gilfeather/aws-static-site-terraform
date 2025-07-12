function handler(event) {
    var response = event.response;
    var headers = response.headers;

    // セキュリティヘッダーを追加
    headers['strict-transport-security'] = { 
        value: 'max-age=63072000; includeSubdomains; preload'
    };
    
    headers['content-security-policy'] = { 
        value: "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self'"
    };
    
    headers['x-content-type-options'] = { 
        value: 'nosniff'
    };
    
    headers['x-frame-options'] = { 
        value: 'DENY'
    };
    
    headers['x-xss-protection'] = { 
        value: '1; mode=block'
    };
    
    headers['referrer-policy'] = { 
        value: 'strict-origin-when-cross-origin'
    };
    
    headers['permissions-policy'] = { 
        value: 'geolocation=(), microphone=(), camera=()'
    };

    return response;
}