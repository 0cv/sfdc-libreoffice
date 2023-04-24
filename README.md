# Salesforce Office Document Converter based on LibreOffice


## Description

HTTP Web Go app which converts office documents (word) to a PDF and saves it back on Salesforce. Salesforce sends the ContentVersionId of the document to convert, the app queries Salesforce, retrieve the document, convert the office document to a PDF through LibreOfficeKit and save the PDF back to Salesforce. It's linked to the Parent ID provided in the request.

The Salesforce session ID is sent also from Salesforce, so that the lambda doesn't perform any authentication


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

From the Salesforce Console
`new AwsLambdaInvoke().invokeLambda('0686T00000QfQjQQAD', '500d0000005e07B');`

