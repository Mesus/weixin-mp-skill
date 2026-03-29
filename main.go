package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/go-resty/resty/v2"
)

type GeneralErrorsResponse struct {
	ErrCode int    `json:"errcode"`
	ErrMsg  string `json:"errmsg"`
}
type AuthResponse struct {
	AccessToken string `json:"access_token"`
	ExpiresIn   int    `json:"expires_in"`
}

func getAuth(appid, secret string) (string, error) {
	client := resty.New()
	var r AuthResponse
	_, err := client.R().
		SetQueryParam("grant_type", "client_credential").
		SetQueryParam("appid", appid).
		SetQueryParam("secret", secret).
		SetResult(&r).
		Get("https://api.weixin.qq.com/cgi-bin/token")
	if err != nil {
		return "", err
	}
	//{
	//	"errcode": 42001,
	//	"errmsg": "access_token expired rid: 69c666a2-31ce2f4d-497c5a06"
	//}
	return r.AccessToken, nil
}

type UploadImageResponse struct {
	Url string `json:"url"`
}

func uploadArticleImage(accessToken, path string) (string, error) {
	client := resty.New()
	resp, err := client.R().
		SetFile("media", path). //Only jpg/png,<1MB
		Post("https://api.weixin.qq.com/cgi-bin/media/uploadimg?access_token=" + accessToken)
	if err != nil {
		return "", err
	}

	var errResp GeneralErrorsResponse
	err = json.Unmarshal(resp.Body(), &errResp)
	if err != nil {
		return "", err
	}

	if errResp.ErrCode != 0 {
		return "", fmt.Errorf("API error %d: %s", errResp.ErrCode, errResp.ErrMsg)
	}

	var r UploadImageResponse
	err = json.Unmarshal(resp.Body(), &r)
	if err != nil {
		return "", err
	}

	return r.Url, nil
}

type UploadCoverResponse struct {
	MediaId  string `json:"mediaId"`
	MediaID2 string `json:"media_id"`
	Url      string `json:"url"`
}

func uploadCoverImage(accessToken, path string) (string, error) {
	client := resty.New()
	resp, err := client.R().
		SetFile("media", path). //Only jpg/png,<1MB
		Post("https://api.weixin.qq.com/cgi-bin/material/add_material?access_token=" + accessToken + "&type=image")
	if err != nil {
		return "", err
	}

	var errResp GeneralErrorsResponse
	err = json.Unmarshal(resp.Body(), &errResp)
	if err != nil {
		return "", err
	}

	if errResp.ErrCode != 0 {
		return "", fmt.Errorf("API error %d: %s", errResp.ErrCode, errResp.ErrMsg)
	}

	var r UploadCoverResponse
	err = json.Unmarshal(resp.Body(), &r)
	if err != nil {
		return "", err
	}

	if r.MediaId != "" {
		return r.MediaId, nil
	}
	if r.MediaID2 != "" {
		return r.MediaID2, nil
	}
	return "", fmt.Errorf("uploadCoverImage returned empty mediaId/media_id")
}

type AddDraftReq struct {
	Title        string `json:"title"`
	Author       string `json:"author"`
	Content      string `json:"content"`
	Digest       string `json:"digest"`
	ThumbMediaId string `json:"thumb_media_id"`
}
type AddDraftResponse struct {
	MediaId string `json:"media_id"`
}
type AddDraftPayload struct {
	Articles []AddDraftReq `json:"articles"`
}

func addDraft(accessToken string, reqData AddDraftReq) (string, error) {
	client := resty.New()
	payload := AddDraftPayload{
		Articles: []AddDraftReq{reqData},
	}

	resp, err := client.R().
		SetHeader("Content-Type", "application/json"). // 可省略,resty 会根据 Body 自动设
		SetBody(payload).                              // 微信 draft/add 需要 {"articles":[...]}
		Post("https://api.weixin.qq.com/cgi-bin/draft/add?access_token=" + accessToken)
	if err != nil {
		return "", err
	}

	var errResp GeneralErrorsResponse
	err = json.Unmarshal(resp.Body(), &errResp)
	if err != nil {
		return "", err
	}

	if errResp.ErrCode != 0 {
		return "", fmt.Errorf("API error %d: %s", errResp.ErrCode, errResp.ErrMsg)
	}

	var respData AddDraftResponse
	err = json.Unmarshal(resp.Body(), &respData)
	if err != nil {
		return "", err
	}

	return respData.MediaId, nil
}
func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: mp-weixin-skill <command> [options]")
		fmt.Println("\nCommands:")
		fmt.Println("  getAuth              - Get access token")
		fmt.Println("  uploadArticleImage   - Upload article image")
		fmt.Println("  uploadCoverImage     - Upload cover image")
		fmt.Println("  addDraft             - Add draft article")
		os.Exit(1)
	}

	command := os.Args[1]

	switch command {
	case "getAuth":
		handleGetAuth()
	case "uploadArticleImage":
		handleUploadArticleImage()
	case "uploadCoverImage":
		handleUploadCoverImage()
	case "addDraft":
		handleAddDraft()
	default:
		fmt.Printf("Unknown command: %s\n", command)
		os.Exit(1)
	}
}

func loadCredentials() (appid, secret string, err error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", "", fmt.Errorf("failed to get home directory: %w", err)
	}

	credFile := filepath.Join(homeDir, ".weixin_credentials")
	file, err := os.Open(credFile)
	if err != nil {
		return "", "", fmt.Errorf("failed to open credentials file %s: %w", credFile, err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		switch key {
		case "appid":
			appid = value
		case "secret":
			secret = value
		}
	}

	if err := scanner.Err(); err != nil {
		return "", "", fmt.Errorf("error reading credentials file: %w", err)
	}

	if appid == "" || secret == "" {
		return "", "", fmt.Errorf("appid or secret not found in credentials file")
	}

	return appid, secret, nil
}

func handleGetAuth() {
	fs := flag.NewFlagSet("getAuth", flag.ExitOnError)
	fs.Parse(os.Args[2:])

	appid, secret, err := loadCredentials()
	if err != nil {
		fmt.Printf("Error loading credentials: %v\n", err)
		os.Exit(1)
	}

	accessToken, err := getAuth(appid, secret)
	if err != nil {
		fmt.Printf("Error getting auth: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("{\"access_token\": \"%s\"}\n", accessToken)
}

func handleUploadArticleImage() {
	fs := flag.NewFlagSet("uploadArticleImage", flag.ExitOnError)
	accessToken := fs.String("token", "", "Access token (required)")
	path := fs.String("path", "", "Image file path (required)")
	fs.Parse(os.Args[2:])

	if *accessToken == "" || *path == "" {
		fmt.Println("Error: token and path are required")
		fs.PrintDefaults()
		os.Exit(1)
	}

	url, err := uploadArticleImage(*accessToken, *path)
	if err != nil {
		fmt.Printf("Error uploading article image: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("{\"url\": \"%s\"}\n", url)
}

func handleUploadCoverImage() {
	fs := flag.NewFlagSet("uploadCoverImage", flag.ExitOnError)
	accessToken := fs.String("token", "", "Access token (required)")
	path := fs.String("path", "", "Image file path (required)")
	fs.Parse(os.Args[2:])

	if *accessToken == "" || *path == "" {
		fmt.Println("Error: token and path are required")
		fs.PrintDefaults()
		os.Exit(1)
	}

	url, err := uploadCoverImage(*accessToken, *path)
	if err != nil {
		fmt.Printf("Error uploading cover image: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("{\"mediaId\": \"%s\"}\n", url)
}

func handleAddDraft() {
	fs := flag.NewFlagSet("addDraft", flag.ExitOnError)
	accessToken := fs.String("token", "", "Access token (required)")
	title := fs.String("title", "", "Article title (required)")
	author := fs.String("author", "", "Article author")
	contentPath := fs.String("content-file", "", "Article content file path (required)")
	digest := fs.String("digest", "", "Article digest")
	thumbMediaId := fs.String("thumb-media-id", "", "Thumb media ID (required)")
	fs.Parse(os.Args[2:])

	if *accessToken == "" || *title == "" || *contentPath == "" || *thumbMediaId == "" {
		fmt.Println("Error: token, title, content-file, and thumb-media-id are required")
		fs.PrintDefaults()
		os.Exit(1)
	}

	contentBytes, err := os.ReadFile(*contentPath)
	if err != nil {
		fmt.Printf("Error reading content file: %v\n", err)
		os.Exit(1)
	}
	content := string(contentBytes)

	reqData := AddDraftReq{
		Title:        *title,
		Author:       *author,
		Content:      content,
		Digest:       *digest,
		ThumbMediaId: *thumbMediaId,
	}

	mediaId, err := addDraft(*accessToken, reqData)
	if err != nil {
		fmt.Printf("Error adding draft: %v\n", err)
		os.Exit(1)
	}

	result := map[string]string{"media_id": mediaId}
	jsonOutput, _ := json.Marshal(result)
	fmt.Println(string(jsonOutput))
}
