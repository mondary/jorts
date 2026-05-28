package security

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
)

type SecurityService struct {
	mu      sync.Mutex
	key     []byte
	enabled bool
	keyPath string
}

var Default *SecurityService

func Init(dataDir string) error {
	keyPath := filepath.Join(dataDir, ".deck_key")
	Default = &SecurityService{
		keyPath: keyPath,
	}
	return Default.loadOrCreateKey()
}

func (s *SecurityService) loadOrCreateKey() error {
	data, err := os.ReadFile(s.keyPath)
	if err == nil && len(data) > 0 {
		decoded, err := base64.StdEncoding.DecodeString(string(data))
		if err == nil && len(decoded) == 32 {
			s.key = decoded
			return nil
		}
	}

	key := make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return fmt.Errorf("failed to generate key: %w", err)
	}
	s.key = key

	encoded := base64.StdEncoding.EncodeToString(key)
	os.MkdirAll(filepath.Dir(s.keyPath), 0700)
	return os.WriteFile(s.keyPath, []byte(encoded), 0600)
}

func (s *SecurityService) SetEnabled(enabled bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.enabled = enabled
}

func (s *SecurityService) IsEnabled() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.enabled
}

func (s *SecurityService) Encrypt(plaintext []byte) ([]byte, error) {
	s.mu.Lock()
	key := s.key
	s.mu.Unlock()

	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}

	return gcm.Seal(nonce, nonce, plaintext, nil), nil
}

func (s *SecurityService) Decrypt(ciphertext []byte) ([]byte, error) {
	s.mu.Lock()
	key := s.key
	s.mu.Unlock()

	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}

	nonceSize := gcm.NonceSize()
	if len(ciphertext) < nonceSize {
		return nil, fmt.Errorf("ciphertext too short")
	}

	nonce, ciphertext := ciphertext[:nonceSize], ciphertext[nonceSize:]
	return gcm.Open(nil, nonce, ciphertext, nil)
}

func (s *SecurityService) EncryptString(plaintext string) (string, error) {
	data, err := s.Encrypt([]byte(plaintext))
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(data), nil
}

func (s *SecurityService) DecryptString(encoded string) (string, error) {
	data, err := base64.StdEncoding.DecodeString(encoded)
	if err != nil {
		return "", err
	}
	decrypted, err := s.Decrypt(data)
	if err != nil {
		return "", err
	}
	return string(decrypted), nil
}

type SensitiveDataCheck struct {
	IsCreditCard bool `json:"isCreditCard"`
	IsIDNumber   bool `json:"isIdNumber"`
}

func CheckSensitiveData(text string) SensitiveDataCheck {
	return SensitiveDataCheck{
		IsCreditCard: isLuhnValid(text),
	}
}

func isLuhnValid(s string) bool {
	var digits []int
	for _, c := range s {
		if c >= '0' && c <= '9' {
			digits = append(digits, int(c-'0'))
		}
	}
	if len(digits) < 13 || len(digits) > 19 {
		return false
	}

	sum := 0
	parity := len(digits) % 2
	for i, d := range digits {
		if i%2 == parity {
			d *= 2
			if d > 9 {
				d -= 9
			}
		}
		sum += d
	}
	return sum%10 == 0
}

func EncryptJSON(v interface{}) (string, error) {
	data, err := json.Marshal(v)
	if err != nil {
		return "", err
	}
	return Default.EncryptString(string(data))
}

func DecryptJSON(encoded string, v interface{}) error {
	decrypted, err := Default.DecryptString(encoded)
	if err != nil {
		return err
	}
	return json.Unmarshal([]byte(decrypted), v)
}
