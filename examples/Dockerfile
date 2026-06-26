FROM ubuntu:26.04

WORKDIR /app
ADD public /app/public
ADD target/release/bin/main /app/main

EXPOSE 8080
CMD ["/app/main"]