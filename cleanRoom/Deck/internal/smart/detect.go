package smart

import (
	"regexp"
	"strings"
)

type ContentType struct {
	IsEmail    bool   `json:"isEmail"`
	IsURL      bool   `json:"isURL"`
	IsPhone    bool   `json:"isPhone"`
	IsCode     bool   `json:"isCode"`
	IsJWT      bool   `json:"isJWT"`
	IsBase64   bool   `json:"isBase64"`
	IsJSON     bool   `json:"isJSON"`
	IsMath     bool   `json:"isMath"`
	IsMarkdown bool   `json:"isMarkdown"`
	Language   string `json:"language,omitempty"`
}

var (
	emailRe   = regexp.MustCompile(`[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}`)
	urlRe     = regexp.MustCompile(`https?://[^\s<>]+|www\.[^\s<>]+\.[a-zA-Z]{2,}`)
	phoneRe   = regexp.MustCompile(`(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}`)
	jwtRe     = regexp.MustCompile(`^eyJ[a-zA-Z0-9_-]+\.eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+$`)
	base64Re  = regexp.MustCompile(`^[A-Za-z0-9+/]+=*$`)
	mathRe    = regexp.MustCompile(`^[\d\s+\-*/().%^]+$`)
	mdHeaders = regexp.MustCompile(`^#{1,6}\s`)
	mdLinks   = regexp.MustCompile(`\[.*?\]\(.*?\)`)
	mdCode    = regexp.MustCompile("```")
)

func Detect(text string) ContentType {
	ct := ContentType{}
	if len(text) == 0 {
		return ct
	}

	ct.IsEmail = emailRe.MatchString(text)
	ct.IsURL = urlRe.MatchString(text)
	ct.IsPhone = phoneRe.MatchString(text)
	ct.IsJWT = jwtRe.MatchString(strings.TrimSpace(text))
	ct.IsBase64 = isLikelyBase64(text)
	ct.IsJSON = isJSON(text)
	ct.IsMath = isMathExpression(text)
	ct.IsMarkdown = isMarkdown(text)
	ct.IsCode, ct.Language = detectCode(text)

	return ct
}

func isLikelyBase64(s string) bool {
	s = strings.TrimSpace(s)
	if len(s) < 16 || len(s)%4 != 0 {
		return false
	}
	return base64Re.MatchString(s)
}

func isJSON(s string) bool {
	s = strings.TrimSpace(s)
	return (strings.HasPrefix(s, "{") && strings.HasSuffix(s, "}")) ||
		(strings.HasPrefix(s, "[") && strings.HasSuffix(s, "]"))
}

func isMathExpression(s string) bool {
	s = strings.TrimSpace(s)
	if len(s) < 3 {
		return false
	}
	if !mathRe.MatchString(s) {
		return false
	}
	hasDigit := false
	for _, c := range s {
		if c >= '0' && c <= '9' {
			hasDigit = true
			break
		}
	}
	return hasDigit && (strings.ContainsAny(s, "+-*/%^"))
}

func isMarkdown(s string) bool {
	lines := strings.Split(s, "\n")
	score := 0
	for _, line := range lines {
		if mdHeaders.MatchString(line) {
			score++
		}
		if mdLinks.MatchString(line) {
			score++
		}
		if strings.HasPrefix(line, "- ") || strings.HasPrefix(line, "* ") {
			score++
		}
	}
	return score >= 2 || mdCode.MatchString(s)
}

func detectCode(s string) (bool, string) {
	lines := strings.Split(s, "\n")
	if len(lines) < 2 {
		return false, ""
	}

	lang := ""
	score := 0

	if strings.Contains(s, "func ") && strings.Contains(s, ":=") {
		lang = "Go"
		score += 3
	}
	if strings.Contains(s, "import ") && strings.Contains(s, "from ") {
		lang = "Python"
		score += 3
	}
	if strings.Contains(s, "function ") || strings.Contains(s, "const ") && strings.Contains(s, "=>") {
		lang = "JavaScript"
		score += 3
	}
	if strings.Contains(s, "class ") && strings.Contains(s, "public ") {
		lang = "Java"
		score += 3
	}
	if strings.Contains(s, "struct ") && strings.Contains(s, "impl ") {
		lang = "Rust"
		score += 3
	}
	if strings.Contains(s, "var ") && strings.Contains(s, "let ") {
		if lang == "" {
			lang = "Swift"
		}
		score += 2
	}
	if strings.Contains(s, "#include") {
		lang = "C/C++"
		score += 3
	}
	if strings.Contains(s, "<?php") {
		lang = "PHP"
		score += 3
	}
	if strings.Contains(s, "<!DOCTYPE") || strings.Contains(s, "<html") {
		lang = "HTML"
		score += 3
	}
	if strings.Contains(s, "SELECT ") && strings.Contains(s, " FROM ") {
		lang = "SQL"
		score += 3
	}

	if score < 2 {
		braceCount := strings.Count(s, "{") + strings.Count(s, "}")
		parenCount := strings.Count(s, "(") + strings.Count(s, ")")
		if braceCount >= 4 && parenCount >= 4 {
			score += 2
		}
	}

	return score >= 2, lang
}
