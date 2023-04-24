# Salesforce Office Document Converter based on LibreOffice


## Description

An HTTP Web Go app designed to convert office documents (such as Word files) into PDFs and save them back to Salesforce. Salesforce sends the ContentVersionId of the document to be converted, the parent ID to which the PDF will be uploaded to; the app then queries Salesforce, retrieves the document, and converts the office document into a PDF using LibreOfficeKit. Afterward, the PDF is saved back to Salesforce and linked to the Parent ID provided in the request.

The Salesforce session ID is also sent from Salesforce, which allows the lambda function to bypass any authentication process.


## Pre-requisite

The applications comprise two primary tasks, each running on a separate Lambda function:

1- Rename `Makefile.sample` to `Makefile`

2- Populate variables in `Makefile`:
- `IMAGE_NAME` e.g. sfdc_libreoffice
- `REGION_ID` e.g. us-east-1
- `ACCOUNT_ID` your AWS account ID
- `ROLE_ID` provide a valid role, or create a new one

3- Deploy the Apex Classes to Salesforce. Set the placeholders in `AwsLambdaInvoke.cls` to your AWS account

4- IAM running user shall have this policy. Replace `REGION_ID`, `ACCOUNT_ID`, `IMAGE_NAME` accordingly
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "lambda:InvokeFunctionUrl",
            "Resource": "arn:aws:lambda:REGION_ID:ACCOUNT_ID:function:IMAGE_NAME",
            "Condition": {
                "StringEquals": {
                    "lambda:FunctionUrlAuthType": "AWS_IAM"
                }
            }
        }
    ]
}
```


## Development

- `make login`   # only once every few hours
- `make init`    # execute once to create resources
- `make deploy`  # for every incremental build


## Run

From the Salesforce Console:

`new AwsLambdaInvoke().invokeLambda('0686T00000QfQjQQAD', '500d0000005e07B');`

