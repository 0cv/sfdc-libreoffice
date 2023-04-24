# 1.13 due to a bug in libreoffice https://github.com/dveselov/go-libreofficekit/issues/13
FROM golang:1.13 as sfdc_libreoffice

# Install various libs. LibreOfficeKit and its dependencies.
RUN apt-get update
RUN apt-get install -y software-properties-common 
RUN apt-get install -y libreoffice libreofficekit-dev
RUN apt-get install -y clang libc++-dev libc++abi-dev cmake ninja-build

# just checking that libreoffice and libreofficekit is in both of these folders
RUN ls -la /usr/lib/
RUN ls -la /usr/include/

# define the path to libre office
ENV LO_INCLUDE_PATH=/usr/include/LibreOfficeKit

WORKDIR "/app"

COPY go.mod go.sum main.go /app/

# download mods
RUN go mod download

# build the app and save the target to /app/bootstrap, our entry point to the Docker image
RUN GOOS=linux go build -v -o /app/bootstrap

CMD [ "./bootstrap" ]
