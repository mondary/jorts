package transform

import (
	"crypto/md5"
	"encoding/base64"
	"encoding/hex"
	"bytes"
	"encoding/json"
	"fmt"
	"net/url"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

type TransformCode string

const (
	TransformJSONFormat    TransformCode = "json_format"
	TransformJSONMinify    TransformCode = "json_minify"
	TransformURLEncode     TransformCode = "url_encode"
	TransformURLDecode     TransformCode = "url_decode"
	TransformBase64Encode  TransformCode = "base64_encode"
	TransformBase64Decode  TransformCode = "base64_decode"
	TransformCamelCase     TransformCode = "camel_case"
	TransformSnakeCase     TransformCode = "snake_case"
	TransformUpperCase     TransformCode = "upper_case"
	TransformLowerCase     TransformCode = "lower_case"
	TransformTrimWhitespace TransformCode = "trim_whitespace"
	TransformHTMLEscape    TransformCode = "html_escape"
	TransformHTMLUnescape  TransformCode = "html_unescape"
	TransformMD5Hash       TransformCode = "md5_hash"
	TransformLineSort      TransformCode = "line_sort"
	TransformLineDedup     TransformCode = "line_dedup"
	TransformReverse       TransformCode = "reverse"
	TransformTimestamp     TransformCode = "timestamp"
)

type TransformInfo struct {
	Code        TransformCode `json:"code"`
	Name        string        `json:"name"`
	Description string        `json:"description"`
}

var Transforms = []TransformInfo{
	{TransformJSONFormat, "JSON Format", "Pretty-print JSON"},
	{TransformJSONMinify, "JSON Minify", "Minify JSON"},
	{TransformURLEncode, "URL Encode", "Encode for URL"},
	{TransformURLDecode, "URL Decode", "Decode URL encoding"},
	{TransformBase64Encode, "Base64 Encode", "Encode to Base64"},
	{TransformBase64Decode, "Base64 Decode", "Decode from Base64"},
	{TransformCamelCase, "camelCase", "Convert to camelCase"},
	{TransformSnakeCase, "snake_case", "Convert to snake_case"},
	{TransformUpperCase, "UPPERCASE", "Convert to uppercase"},
	{TransformLowerCase, "lowercase", "Convert to lowercase"},
	{TransformTrimWhitespace, "Trim Whitespace", "Remove leading/trailing whitespace"},
	{TransformHTMLEscape, "HTML Escape", "Escape HTML entities"},
	{TransformHTMLUnescape, "HTML Unescape", "Unescape HTML entities"},
	{TransformMD5Hash, "MD5 Hash", "Generate MD5 hash"},
	{TransformLineSort, "Sort Lines", "Sort lines alphabetically"},
	{TransformLineDedup, "Dedup Lines", "Remove duplicate lines"},
	{TransformReverse, "Reverse", "Reverse the text"},
	{TransformTimestamp, "Timestamp", "Parse Unix timestamp to date"},
}

func Apply(code TransformCode, input string) (string, error) {
	switch code {
	case TransformJSONFormat:
		return jsonFormat(input)
	case TransformJSONMinify:
		return jsonMinify(input)
	case TransformURLEncode:
		return url.QueryEscape(input), nil
	case TransformURLDecode:
		return url.QueryUnescape(input)
	case TransformBase64Encode:
		return base64.StdEncoding.EncodeToString([]byte(input)), nil
	case TransformBase64Decode:
		decoded, err := base64.StdEncoding.DecodeString(input)
		return string(decoded), err
	case TransformCamelCase:
		return toCamelCase(input), nil
	case TransformSnakeCase:
		return toSnakeCase(input), nil
	case TransformUpperCase:
		return strings.ToUpper(input), nil
	case TransformLowerCase:
		return strings.ToLower(input), nil
	case TransformTrimWhitespace:
		return strings.TrimSpace(input), nil
	case TransformHTMLEscape:
		return htmlEscape(input), nil
	case TransformHTMLUnescape:
		return htmlUnescape(input), nil
	case TransformMD5Hash:
		hash := md5.Sum([]byte(input))
		return hex.EncodeToString(hash[:]), nil
	case TransformLineSort:
		return lineSort(input), nil
	case TransformLineDedup:
		return lineDedup(input), nil
	case TransformReverse:
		runes := []rune(input)
		for i, j := 0, len(runes)-1; i < j; i, j = i+1, j-1 {
			runes[i], runes[j] = runes[j], runes[i]
		}
		return string(runes), nil
	case TransformTimestamp:
		return parseTimestamp(input)
	default:
		return "", fmt.Errorf("unknown transform: %s", code)
	}
}

func jsonFormat(s string) (string, error) {
	var buf bytes.Buffer
	err := json.Indent(&buf, []byte(s), "", "  ")
	return buf.String(), err
}

func jsonMinify(s string) (string, error) {
	var buf bytes.Buffer
	err := json.Compact(&buf, []byte(s))
	return buf.String(), err
}

var camelRe = regexp.MustCompile(`[\s_-]+(.)`)

func toCamelCase(s string) string {
	s = strings.ToLower(s)
	result := camelRe.ReplaceAllStringFunc(s, func(match string) string {
		return strings.ToUpper(match[len(match)-1:])
	})
	return result
}

var snakeRe = regexp.MustCompile(`[A-Z]`)

func toSnakeCase(s string) string {
	s = strings.TrimSpace(s)
	result := snakeRe.ReplaceAllStringFunc(s, func(match string) string {
		return "_" + strings.ToLower(match)
	})
	return strings.TrimPrefix(strings.ToLower(result), "_")
}

func htmlEscape(s string) string {
	s = strings.ReplaceAll(s, "&", "&amp;")
	s = strings.ReplaceAll(s, "<", "&lt;")
	s = strings.ReplaceAll(s, ">", "&gt;")
	s = strings.ReplaceAll(s, `"`, "&quot;")
	s = strings.ReplaceAll(s, "'", "&#39;")
	return s
}

func htmlUnescape(s string) string {
	s = strings.ReplaceAll(s, "&lt;", "<")
	s = strings.ReplaceAll(s, "&gt;", ">")
	s = strings.ReplaceAll(s, "&quot;", "\"")
	s = strings.ReplaceAll(s, "&#39;", "'")
	s = strings.ReplaceAll(s, "&amp;", "&")
	return s
}

func lineSort(s string) string {
	lines := strings.Split(s, "\n")
	sort.Strings(lines)
	return strings.Join(lines, "\n")
}

func lineDedup(s string) string {
	lines := strings.Split(s, "\n")
	seen := make(map[string]bool)
	var result []string
	for _, line := range lines {
		if !seen[line] {
			seen[line] = true
			result = append(result, line)
		}
	}
	return strings.Join(result, "\n")
}

func parseTimestamp(s string) (string, error) {
	s = strings.TrimSpace(s)
	ts, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		return "", fmt.Errorf("not a valid timestamp: %s", s)
	}
	return time.Unix(ts, 0).Format(time.RFC3339), nil
}
