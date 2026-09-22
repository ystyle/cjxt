# cjxt 演示站镜像（产物打包：宿主工具链产出二进制 → 镜像只打包）
#
# 构建：docker compose -f ~/docker/cjxt-demo/docker-compose.yml build
#       （context = 本目录；.dockerignore 只放行 public 与 target/release/bin/main）
#
# 基础镜像必须与**宿主编译环境**的 glibc 一致：二进制在宿主链接，动态依赖 libc/libm/
# libstdc++/libgcc_s。宿主是 Arch（glibc 2.44）时，ubuntu:26.04（glibc 2.43）会直接
# 崩溃循环 —— `/app/main: /usr/lib/x86_64-linux-gnu/libm.so.6: version 'GLIBC_2.44' not found`。
# archlinux:latest 自带 glibc/libstdc++/libgcc_s，与宿主对齐。
FROM archlinux:latest

# 时区与根证书（日期/日历组件按本地时区显示；出站 HTTPS 需根证书）
RUN pacman -Sy --noconfirm tzdata ca-certificates \
    && rm -rf /var/cache/pacman/pkg

WORKDIR /app
ADD public /app/public
ADD target/release/bin/main /app/main
# 上传目录（App.serveUpload 存的相对路径；挂卷时由 volume 提供，无卷兜底创建）
RUN mkdir -p /app/uploads

EXPOSE 8080
CMD ["/app/main"]
