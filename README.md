# 微信公众号 CLI 工具 / WeChat MP CLI Tool

[English](#english) | [中文](#chinese)

---

<a name="chinese"></a>
## 中文文档

### 简介

这是一个用于管理微信公众号的命令行工具，支持获取访问令牌、上传图片和创建草稿文章等功能。

### 功能特性

- ✅ 获取微信公众号访问令牌（Access Token）
- ✅ 上传文章图片
- ✅ 上传封面图片
- ✅ 创建草稿文章

### 安装

#### 前置要求

- Go 1.16 或更高版本
- 微信公众号 AppID 和 AppSecret

#### 编译

```bash
git clone <repository-url>
cd mp-weixin-skill
go build -o mp-weixin-skill main.go
```

### 配置

1. 复制示例配置文件到用户主目录：

```bash
cp weixin_credentials.example ~/.weixin_credentials
```

2. 编辑 `~/.weixin_credentials` 文件，填入你的微信公众号凭证：

```
appid=your_app_id_here
secret=your_app_secret_here
```

**注意：** 请妥善保管此文件，不要将其提交到版本控制系统。

### 使用方法

#### 1. 获取访问令牌

```bash
./mp-weixin-skill getAuth
```

**输出示例：**
```json
{"access_token": "your_access_token_here"}
```

#### 2. 上传文章图片

```bash
./mp-weixin-skill uploadArticleImage -token=ACCESS_TOKEN -path=/path/to/image.jpg
```

**参数说明：**
- `-token`: 访问令牌（必需）
- `-path`: 图片文件路径（必需，仅支持 jpg/png，小于 1MB）

**输出示例：**
```json
{"url": "http://mmbiz.qpic.cn/..."}
```

#### 3. 上传封面图片

```bash
./mp-weixin-skill uploadCoverImage -token=ACCESS_TOKEN -path=/path/to/cover.jpg
```

**参数说明：**
- `-token`: 访问令牌（必需）
- `-path`: 图片文件路径（必需，仅支持 jpg/png，小于 1MB）

**输出示例：**
```json
{"mediaId": "media_id_here"}
```

#### 4. 创建草稿文章

```bash
./mp-weixin-skill addDraft \
  -token=ACCESS_TOKEN \
  -title="文章标题" \
  -author="作者名称" \
  -content-file=/path/to/article.txt \
  -digest="文章摘要" \
  -thumb-media-id=MEDIA_ID
```

**参数说明：**
- `-token`: 访问令牌（必需）
- `-title`: 文章标题（必需）
- `-author`: 作者名称（可选）
- `-content-file`: 文章内容文件路径（必需）
- `-digest`: 文章摘要（可选）
- `-thumb-media-id`: 封面图片的 media_id（必需）

**输出示例：**
```json
{"media_id": "draft_media_id_here"}
```

### 工作流程示例

完整的发布文章流程：

```bash
# 1. 获取访问令牌
TOKEN=$(./mp-weixin-skill getAuth | jq -r '.access_token')

# 2. 上传封面图片
THUMB_MEDIA_ID=$(./mp-weixin-skill uploadCoverImage -token=$TOKEN -path=cover.jpg | jq -r '.mediaId')

# 3. 创建草稿（文章内容保存在 article.txt 文件中）
./mp-weixin-skill addDraft \
  -token=$TOKEN \
  -title="我的文章标题" \
  -author="作者" \
  -content-file=article.txt \
  -digest="这是文章摘要" \
  -thumb-media-id=$THUMB_MEDIA_ID
```

### 错误处理

所有 API 调用都会检查微信接口返回的错误码。如果出现错误，程序会输出详细的错误信息：

```
Error getting auth: API error 40001: invalid credential, access_token is invalid or not latest
```

### 依赖项

- [go-resty/resty](https://github.com/go-resty/resty) - HTTP 客户端库

### 许可证

MIT License

---

<a name="english"></a>
## English Documentation

### Introduction

A command-line tool for managing WeChat Official Accounts (MP), supporting access token retrieval, image uploads, and draft article creation.

### Features

- ✅ Get WeChat MP Access Token
- ✅ Upload article images
- ✅ Upload cover images
- ✅ Create draft articles

### Installation

#### Prerequisites

- Go 1.16 or higher
- WeChat Official Account AppID and AppSecret

#### Build

```bash
git clone <repository-url>
cd mp-weixin-skill
go build -o mp-weixin-skill main.go
```

### Configuration

1. Copy the example credentials file to your home directory:

```bash
cp weixin_credentials.example ~/.weixin_credentials
```

2. Edit `~/.weixin_credentials` and fill in your WeChat MP credentials:

```
appid=your_app_id_here
secret=your_app_secret_here
```

**Note:** Keep this file secure and do not commit it to version control.

### Usage

#### 1. Get Access Token

```bash
./mp-weixin-skill getAuth
```

**Example output:**
```json
{"access_token": "your_access_token_here"}
```

#### 2. Upload Article Image

```bash
./mp-weixin-skill uploadArticleImage -token=ACCESS_TOKEN -path=/path/to/image.jpg
```

**Parameters:**
- `-token`: Access token (required)
- `-path`: Image file path (required, jpg/png only, < 1MB)

**Example output:**
```json
{"url": "http://mmbiz.qpic.cn/..."}
```

#### 3. Upload Cover Image

```bash
./mp-weixin-skill uploadCoverImage -token=ACCESS_TOKEN -path=/path/to/cover.jpg
```

**Parameters:**
- `-token`: Access token (required)
- `-path`: Image file path (required, jpg/png only, < 1MB)

**Example output:**
```json
{"mediaId": "media_id_here"}
```

#### 4. Create Draft Article

```bash
./mp-weixin-skill addDraft \
  -token=ACCESS_TOKEN \
  -title="Article Title" \
  -author="Author Name" \
  -content-file=/path/to/article.txt \
  -digest="Article summary" \
  -thumb-media-id=MEDIA_ID
```

**Parameters:**
- `-token`: Access token (required)
- `-title`: Article title (required)
- `-author`: Author name (optional)
- `-content-file`: Article content file path (required)
- `-digest`: Article summary (optional)
- `-thumb-media-id`: Cover image media_id (required)

**Example output:**
```json
{"media_id": "draft_media_id_here"}
```

### Workflow Example

Complete workflow for publishing an article:

```bash
# 1. Get access token
TOKEN=$(./mp-weixin-skill getAuth | jq -r '.access_token')

# 2. Upload cover image
THUMB_MEDIA_ID=$(./mp-weixin-skill uploadCoverImage -token=$TOKEN -path=cover.jpg | jq -r '.mediaId')

# 3. Create draft (article content saved in article.txt)
./mp-weixin-skill addDraft \
  -token=$TOKEN \
  -title="My Article Title" \
  -author="Author" \
  -content-file=article.txt \
  -digest="This is the article summary" \
  -thumb-media-id=$THUMB_MEDIA_ID
```

### Error Handling

All API calls check for error codes returned by the WeChat API. If an error occurs, the program outputs detailed error information:

```
Error getting auth: API error 40001: invalid credential, access_token is invalid or not latest
```

### Dependencies

- [go-resty/resty](https://github.com/go-resty/resty) - HTTP client library

### License

MIT License

---

## Contributing / 贡献

Contributions are welcome! Please feel free to submit a Pull Request.

欢迎贡献！请随时提交 Pull Request。

## Support / 支持

If you encounter any issues, please open an issue on GitHub.

如果遇到任何问题，请在 GitHub 上提交 issue。
