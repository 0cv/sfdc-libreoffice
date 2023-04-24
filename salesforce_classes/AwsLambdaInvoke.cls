public class AwsLambdaInvoke extends AWS {
    public class Request {
        public String sessionID;
        public String instanceURL;
        public String title;
        public String contentVersionID;
        public String parentID;
    }

    public override void init() {
        resource = '/';
        region = 'eu-central-1';
        service = 'lambda';
        host = 'xxxxxxxx.lambda-url.eu-central-1.on.aws';
        endpoint = new Url('https://' + host);
        accessKey = 'AWS_ACCESS_ID';
        method = HttpMethod.XPOST;
        createSigningKey('AWS_ACCESS_SECRET');
    }
    public void invokeLambda(Id contentVersionID, Id parentId) {
        Request request = new Request();
        request.sessionID = UserInfo.getSessionID();
        request.instanceURL = System.Url.getSalesforceBaseURL().toExternalForm();
        request.title = 'big_file';
        request.contentVersionID = contentVersionID; // sample document version, e.g. '0686T00000QfQjQQAD'
        request.parentID = parentId;                 // sample case,             e.g. '500d0000005e07B';
        payload = Blob.valueOf(JSON.Serialize(request));

        HttpResponse response = sendRequest();
        System.debug('## response: ' + response.getBody());
    }
}