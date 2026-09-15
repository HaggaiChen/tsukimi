# Windows 构建指南

本文档介绍如何在 Windows 上构建和运行 tsukimi（本 fork 新增的移植支持）。

## 平台差异说明

Windows 版本与 Linux 版本的差异：

- **视频渲染**：Linux 默认使用 wl-proxy（Wayland 代理 + dmabuf）嵌入 mpv 的 gpu-next 输出；Windows 没有 Wayland，改用 `MPVGLArea`（libmpv render API + GTK GLArea）渲染。
- **MPRIS**（系统媒体控制）：依赖 D-Bus，Windows 下禁用。
- **图像解码**：glycin 的沙箱加载器是 Linux 专属，Windows 下改用 `image` crate 解码；动图（gif 等）只显示静态首帧。
- **GPU Context 偏好设置**：waylandvk/wayland/wlshm 选项只在 Linux 有效，Windows 下该设置组隐藏。
- **hwdec**：Windows 下 `vaapi` 选项映射为 `d3d11va`。

## 使用 CI 构建（推荐）

fork 仓库启用了 `build_windows.yml` workflow：push 到 `main` 或打 tag 后，GitHub Actions 会自动产出 `tsukimi-amd64-windows.zip`（便携包，含全部 DLL），tag 推送会附加到 GitHub Release。

## 本机构建

### 1. 安装 MSYS2

从 https://www.msys2.org 安装 MSYS2，然后打开 **UCRT64** 终端安装依赖：

```bash
pacman -Syu
pacman -S --needed \
  git zip \
  mingw-w64-ucrt-x86_64-meson \
  mingw-w64-ucrt-x86_64-rust \
  mingw-w64-ucrt-x86_64-gcc \
  mingw-w64-ucrt-x86_64-pkgconf \
  mingw-w64-ucrt-x86_64-gtk4 \
  mingw-w64-ucrt-x86_64-libadwaita \
  mingw-w64-ucrt-x86_64-mpv \
  mingw-w64-ucrt-x86_64-gstreamer \
  mingw-w64-ucrt-x86_64-gst-plugins-base \
  mingw-w64-ucrt-x86_64-gst-plugins-good \
  mingw-w64-ucrt-x86_64-gst-plugins-bad \
  mingw-w64-ucrt-x86_64-gst-plugins-ugly \
  mingw-w64-ucrt-x86_64-gst-libav \
  mingw-w64-ucrt-x86_64-libepoxy \
  mingw-w64-ucrt-x86_64-openssl \
  mingw-w64-ucrt-x86_64-blueprint-compiler \
  mingw-w64-ucrt-x86_64-gettext-tools \
  mingw-w64-ucrt-x86_64-adwaita-icon-theme \
  mingw-w64-ucrt-x86_64-ntldd
```

### 2. 构建

```bash
git clone --recursive <你的 fork 地址>
cd tsukimi
meson setup build --prefix=/ucrt64
meson compile -C build
```

开发调试可直接运行 `target/debug/tsukimi.exe`（在 UCRT64 终端中，此时使用 MSYS2 环境里的 gresource / schema）。

### 3. 打便携包

```bash
meson install -C build --destdir "$PWD/staging"
# meson 在 Windows 会把 prefix 解析为带盘符的绝对路径，定位实际安装位置：
exe="$(find "$PWD/staging" -name tsukimi.exe | head -1)"
bash build-aux/package-windows.sh "$(dirname "$(dirname "$exe")")" tsukimi-amd64-windows
```

产出 `tsukimi-amd64-windows.zip`，解压后双击 `tsukimi.exe` 即可运行（无需 MSYS2 环境）。包内布局：

```
tsukimi-amd64-windows/
├── tsukimi.exe           # 主程序
├── *.dll                 # ntldd 解析出的全部依赖 DLL
├── share/                # gresource、gsettings schema、翻译、图标
├── lib/gstreamer-1.0/    # GStreamer 插件
└── etc/fonts/            # fontconfig 配置
```

## 推荐工作流（dev/main 双分支，CI-only）

日常开发只靠 GitHub Actions 构建，无需本地环境：

1. 在 `dev` 分支上改代码，随时 `git push origin dev`——CI 自动构建打包，到 Actions 运行记录的 Artifacts 区域下载 `tsukimi-amd64-windows.zip` 实测。dev 上的提交随便写、随便 force push；
2. 全部就绪后，在 GitHub 上开 dev→main 的 PR，合并时选 **Squash and merge**——main 只增加一个干净提交；
3. 合并后手动打 tag 推送（如 `git tag v26.9.2 && git push origin v26.9.2`），CI 自动创建 Release 并附上 zip；
4. 删除 dev 分支，下次迭代再重新开。

## 便携性

Windows 版是完全便携的：程序启动时会把运行时写入全部重定向到 exe 所在目录——

- `cache/`：图片缓存、GStreamer 插件注册表、fontconfig 缓存
- `config/glib-2.0/settings/keyfile`：应用设置（不会写入 Windows 注册表）

整个目录可以随意移动、删除即卸载。如需恢复系统默认位置，启动前自行设置 `XDG_CACHE_HOME` / `XDG_CONFIG_HOME` / `GSETTINGS_BACKEND` 环境变量即可（程序不会覆盖已设置的变量）。

## 注意事项

- `DANDANAPI_SECRET_KEY` 是上游仓库的私有构建 secret。没有它构建不会失败，但弹幕搜索功能不可用（运行时会记录错误日志）。
- 如果视频区域渲染异常，可以尝试用 `--gsk-renderer ngl` 启动（默认强制 `gl`）。
