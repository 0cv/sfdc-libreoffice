public abstract class AWS {
    //	Post initialization logic (after constructor, before call)
    protected abstract void init();
	
    //	Things we need to know about the service. Set these values in init()
	protected String host;
	protected String region;
	protected String service;
	protected String resource;
	protected String accessKey;
	protected String payloadSha256;
	protected String contentType;  
	protected Url endpoint;
	protected HttpMethod method;
	protected Blob payload;
    
    //	Not used externally, so we hide these values
	Blob signingKey;
	String signature;
	String canonicalRequest;
	DateTime requestTime;
	Map<String, String> queryParams;
	Map<String, String> headerParams;

	public enum HttpMethod {XGET, XPUT, XHEAD, XOPTIONS, XDELETE, XPOST}

    //	Call this constructor with super() in subclasses
	protected AWS() {
		requestTime = DateTime.now();
		queryParams = new Map<String, String>();
		headerParams = new Map<String, String>();
       	payload = Blob.valueOf('');
        contentType = 'application/json';
	}
    
    //	Send a default request
    protected HttpResponse sendRequest() {
		return sendRequest(new Set<Integer> { 200 });
	}    
    
    //	Actually perform the request, and throw exception if response code is not valid
    protected HttpResponse sendRequest(Set<Integer> validCodes) {
        HttpRequest request = createQuerySignedRequest();
        request.setTimeout(120000);
    	HttpResponse response = new Http().send(request);

        if(!validCodes.contains(response.getStatusCode())) {
            System.debug('Response Error: ' + response.getBody());
    		throw new ServiceException(response.getBody());
    	}
    	
        return response;
	}
    
    HttpRequest createQuerySignedRequest(){
        String stringToSign;
        String finalEndpoint;
        String queryString;
        String canonicalHeaders;
        HttpRequest request = new HttpRequest();
		
        init();
        
        request.setMethod(method.name().removeStart('X'));
        payloadSha256 = EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', payload));
        request.setBodyAsBlob(payload);
        
        if(host == null) {
            host = service + '.' + region + '.amazonaws.com';
        }
        
        request.setHeader('Content-type', contentType);
        setHeader('Content-type', contentType);
        setHeader('Host', host);
        
        //Set AUTHPARAMS in the query
        setQueryParam('X-Amz-Algorithm','AWS4-HMAC-SHA256');
        setQueryParam('X-Amz-Credential', String.join(new List<String> {
								accessKey,
								requestTime.formatGMT('yyyyMMdd'),
								region,
								service,
								'aws4_request' 
							},'/'));
        setQueryParam('X-Amz-Date',requestTime.formatGMT('yyyyMMdd\'T\'HHmmss\'Z\''));
        setQueryParam('X-Amz-SignedHeaders', + String.join(new List<String>(headerParams.keySet()),';').toLowerCase());
        
        //Create the signature
        queryString = createCanonicalQueryString();
        canonicalHeaders = createCanonicalHeaders();
        canonicalRequest = createCanonicalRequest(queryString,canonicalHeaders);
        stringToSign = createStringToSign(canonicalRequest);
        createSignature(stringToSign);
        
        //Add the signature at the end
        queryString += '&X-Amz-Signature=' + signature;
        
        finalEndpoint = new Url(endpoint, resource).toExternalForm() + '?'+ queryString;
        
        request.setEndpoint(finalEndpoint);
        
        return request;
    }    
    
    protected void createSigningKey(String secretKey)
    {
        Blob dateKey = signString(Blob.valueOf(requestTime.formatGMT('yyyyMMdd')),Blob.valueOf('AWS4'+secretKey));
        Blob dateRegionKey = signString(Blob.valueOf(region),dateKey);
        Blob dateRegionServiceKey = signString(Blob.valueOf(service),dateRegionKey);
        signingKey = signString(Blob.valueOf('aws4_request'),dateRegionServiceKey);
    }
    
    //	Create a canonical query string (used during signing)
	String createCanonicalQueryString() {
		List<String> results = new List<String>();
        List<String> keys = new List<String>(queryParams.keySet());
        
		keys.sort();
        
        for(String key: keys) {
            results.add(key + '=' + queryParams.get(key));
        }
                                             
        return String.join(results, '&');
	}
    
    //	Create the canonical headers (used for signing)
	String createCanonicalHeaders() {
        List<String> results = new List<String>();
        List<String> keys = new List<String>(headerParams.keySet());
        
        keys.sort();
		
        for(String key: keys) {
			results.add(key + ':' + headerParams.get(key));
		}
        
		return String.join(results, '\n')+'\n';
	}
    
    // Create the entire canonical request
	String createCanonicalRequest(String queryString, String canonicalHeaders) {
        String result = String.join(
		new List<String> {
			method.name().removeStart('X'),					//	METHOD
			new Url(endPoint, resource).getPath(),				//	RESOURCE
			queryString,							//	CANONICAL QUERY STRING
			canonicalHeaders,						//	CANONICAL HEADERS
               		String.join(new List<String>(headerParams.keySet()), ';'),	//	SIGNED HEADERS
			payloadSha256							//	SHA256 PAYLOAD
		},
		'\n');

        return result;
	}
    
    //	Create the entire string to sign
    String createStringToSign(String canonicalRequest) {
        String result = String.join(
            new List<String> {
                'AWS4-HMAC-SHA256',
                    requestTime.formatGMT('yyyyMMdd\'T\'HHmmss\'Z\''),
                    String.join(new List<String>{requestTime.formatGMT('yyyyMMdd'), region, service, 'aws4_request' },'/'),
                    EncodingUtil.convertToHex(Crypto.generateDigest('sha256', Blob.valueof(canonicalRequest)))
                    },
            '\n'
        );

        return result;
    }
    
    private void createSignature(String stringToSign){
        signature =  EncodingUtil.convertToHex(signString(blob.valueof(stringToSign),signingKey));
    }

    //	We have to replace ~ and " " correctly, or we'll break AWS on those two characters
    protected string uriEncode(String value) {
        return value==null? null: EncodingUtil.urlEncode(value, 'utf-8').replaceAll('%7E','~').replaceAll('\\+','%20');
    }
    
	protected void setHeader(String key, String value) {
		headerParams.put(key.toLowerCase(), value);
	}

    protected void setQueryParam(String key, String value) {
		queryParams.put(key.capitalize(), UriEncode(value));
	}  
    
    private Blob signString(Blob msg, Blob key) {
        return Crypto.generateMac('HMACSHA256', msg, key);
    }
    
    public static String getChildNodeText(Dom.XmlNode node, String ns, String name) {
		try {
			return node.getChildElement(name, ns).getText();
		} catch(Exception e) {
			return null;
		}
	}
    
    //	Turns an Amazon exception into something we can present to the user/catch
	public class ServiceException extends Exception {
		public String Code, Message, Resource, RequestId;
	
		public ServiceException(Dom.XmlNode node) {
			String ns = node.getNamespace();
			Code = getChildNodeText(node, ns, 'Code');
			Message = getChildNodeText(node, ns, 'Message');
			Resource = getChildNodeText(node, ns, 'Resource');
			RequestId = getChildNodeText(node, ns, 'RequestId');
		}
        
        public String toString() {
            return JSON.serialize(this);
        }
	}
}