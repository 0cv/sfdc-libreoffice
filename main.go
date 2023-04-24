package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/dveselov/go-libreofficekit"
	"github.com/simpleforce/simpleforce"
)

func main() {
	lambda.Start(HandleRequest)
}

type MyEvent struct {
	SessionID        string `json:"sessionID"`
	InstanceURL      string `json:"instanceURL"`
	Title            string `json:"title"`
	ContentVersionID string `json:"contentVersionID"`
	ParentID         string `json:"parentID"`
}

type FileRequest struct {
	Title        string `json:"Title"`
	PathOnClient string `json:"PathOnClient"`
	VersionData  string `json:"VersionData"`
}

func HandleRequest(ctx context.Context, request events.APIGatewayProxyRequest) (string, error) {
	var event MyEvent
	json.Unmarshal([]byte(request.Body), &event)
	log.Println("Lambda Request URL: ", event.InstanceURL)
	log.Println("Lambda Title: ", event.Title)

	// instantiating
	client := simpleforce.NewClient(event.InstanceURL, simpleforce.DefaultClientID, simpleforce.DefaultAPIVersion)

	// use the session ID as login
	err := client.LoginSessionID(event.InstanceURL, event.SessionID)

	// will be saved in /tmp/ folder
	path := fmt.Sprintf("/tmp/%v.docx", time.Now().UnixNano())

	// download and save file locally
	client.DownloadFile(event.ContentVersionID, path)

	// instantiate libreoffice
	office, err := libreofficekit.NewOffice("/usr/lib/libreoffice/program")
	if err != nil {
		log.Fatalf("Error instantiating new office: %v", err)
	}

	// load document
	document, err := office.LoadDocument(path)
	if err != nil {
		log.Fatalf("Error loading file: %v", err)
	}

	// pdf path is the same as the doc, except it ends with .pdf
	pdfPath := strings.Replace(path, ".docx", ".pdf", -1)

	log.Println("saving PDF at ", pdfPath)

	err = document.SaveAs(pdfPath, "pdf", "")
	if err != nil {
		log.Fatalf("Error saving file: %v", err)
	}

	log.Println("close document...")
	document.Close()
	office.Close()

	log.Println("read file from ", pdfPath)

	// Read file bytes
	fileBytes, err := ioutil.ReadFile(pdfPath)
	if err != nil {
		log.Fatalf("Error reading pdf file: %v", err)
	}

	// Encode bytes to base64
	fileBase64 := base64.StdEncoding.EncodeToString(fileBytes)

	// Basic ContentVersion
	file := FileRequest{
		Title:        event.Title,
		PathOnClient: fmt.Sprintf("%s.pdf", event.Title),
		VersionData:  fileBase64,
	}

	fileMarshalled, err := json.Marshal(file)
	if err != nil {
		log.Fatalln("Error marshaling:", err)
	}

	// ContentVersion as io Reader
	body := bytes.NewReader(fileMarshalled)

	// upload the file to salesforce
	contentVersionBytes, err := client.HttpRequest("POST", fmt.Sprintf("%s/services/data/v55.0/sobjects/ContentVersion", event.InstanceURL), body)

	if err != nil {
		log.Fatalf("Error deleting file: %v", err)
	}

	contentVersion := make(map[string]interface{})
	err = json.Unmarshal(contentVersionBytes, &contentVersion)
	if err != nil {
		log.Fatalf("Error unmarshaling file: %v", err)
	}
	log.Printf("Successfully created the file: %v", contentVersion)

	// query contentversion again to get the ContentDocumentID
	contentVersions, err := client.Query(fmt.Sprintf("SELECT ContentDocumentId FROM ContentVersion WHERE Id = '%s'", contentVersion["id"].(string)))
	if err != nil {
		log.Fatalf("Error querying content version: %v", err)
	}

	log.Printf("Content Versions: %v", contentVersions)

	var contentDocumentId string
	for _, contentVersion := range contentVersions.Records {
		contentDocumentId = contentVersion["ContentDocumentId"].(string)
	}

	// Create the Content Document Link to the Parent Object
	cdl := client.SObject("ContentDocumentLink").
		Set("LinkedEntityId", event.ParentID).
		Set("ContentDocumentId", contentDocumentId).
		Create()
	log.Println("New CDL: ", cdl)

	log.Println("Delete PDF and office local files")
	err = os.Remove(pdfPath)
	err = os.Remove(path)

	// Return the Content Document Link ID
	return fmt.Sprintf(cdl.ID()), nil
}
