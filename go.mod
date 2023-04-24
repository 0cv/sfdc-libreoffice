module test_libreoffice

go 1.20

require (
	github.com/aws/aws-lambda-go v1.39.1
	github.com/dveselov/go-libreofficekit v0.0.0-20180124082231-2bac0eacb65b
	github.com/simpleforce/simpleforce v0.0.0-20220429021116-acf4ac67ef68
)

require github.com/pkg/errors v0.9.1 // indirect

replace github.com/simpleforce/simpleforce => github.com/0cv/simpleforce v0.1.1
