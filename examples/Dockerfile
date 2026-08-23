FROM ubuntu:26.04

WORKDIR /app
ADD public /app/public
ADD target/release/bin/main /app/main
# 上传目录（App.serveUpload 存的相对路径；挂卷时由 volume 提供，无卷兜底创建）
RUN mkdir -p /app/uploads

EXPOSE 8080
CMD ["/app/main"]
