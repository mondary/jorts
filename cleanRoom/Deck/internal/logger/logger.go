package logger

import (
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type Level int

const (
	DEBUG Level = iota
	INFO
	WARNING
	ERROR
)

type Logger struct {
	level     Level
	mu        sync.Mutex
	logDir    string
	file      *os.File
	buffer    []byte
	lastFlush time.Time
	instance  *log.Logger
	created   time.Time
}

var defaultLogger *Logger
var once sync.Once

func Init(logDir string, level Level) error {
	var err error
	once.Do(func() {
		defaultLogger, err = NewLogger(logDir, level)
	})
	return err
}

func Default() *Logger {
	if defaultLogger == nil {
		defaultLogger, _ = NewLogger(
			filepath.Join(os.Getenv("HOME"), "Library", "Application Support", "Deck", "Logs"),
			INFO,
		)
	}
	return defaultLogger
}

func NewLogger(logDir string, level Level) (*Logger, error) {
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create log directory: %w", err)
	}

	l := &Logger{
		level:     level,
		logDir:    logDir,
		buffer:    make([]byte, 0, 64*1024),
		lastFlush: time.Now(),
		created:   time.Now(),
	}

	if err := l.openFile(); err != nil {
		return nil, err
	}

	l.instance = log.New(io.MultiWriter(os.Stderr, &writerHook{l: l}), "", 0)

	go l.flushLoop()
	go l.rotationLoop()
	go l.cleanupLoop()

	return l, nil
}

type writerHook struct {
	l *Logger
}

func (w *writerHook) Write(p []byte) (n int, err error) {
	w.l.mu.Lock()
	defer w.l.mu.Unlock()
	w.l.buffer = append(w.l.buffer, p...)
	if len(w.l.buffer) >= 64*1024 || time.Since(w.l.lastFlush) >= 500*time.Millisecond {
		w.l.flush()
	}
	return len(p), nil
}

func (l *Logger) openFile() error {
	filename := fmt.Sprintf("deck_%s.log", time.Now().Format("2006-01-02"))
	path := filepath.Join(l.logDir, filename)

	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}

	if l.file != nil {
		l.file.Close()
	}
	l.file = f
	return nil
}

func (l *Logger) flush() {
	if l.file != nil && len(l.buffer) > 0 {
		l.file.Write(l.buffer)
		l.buffer = l.buffer[:0]
		l.lastFlush = time.Now()
	}
}

func (l *Logger) Flush() {
	l.mu.Lock()
	defer l.mu.Unlock()
	l.flush()
}

func (l *Logger) flushLoop() {
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()
	for range ticker.C {
		l.mu.Lock()
		l.flush()
		l.mu.Unlock()
	}
}

func (l *Logger) rotationLoop() {
	ticker := time.NewTicker(1 * time.Hour)
	defer ticker.Stop()
	for range ticker.C {
		l.mu.Lock()
		now := time.Now()
		if now.Day() != l.created.Day() || now.Month() != l.created.Month() {
			l.flush()
			l.openFile()
			l.created = now
		}
		l.mu.Unlock()
	}
}

func (l *Logger) cleanupLoop() {
	ticker := time.NewTicker(24 * time.Hour)
	defer ticker.Stop()
	for range ticker.C {
		l.cleanOldLogs()
	}
}

func (l *Logger) cleanOldLogs() {
	entries, err := os.ReadDir(l.logDir)
	if err != nil {
		return
	}
	cutoff := time.Now().AddDate(0, 0, -7)
	for _, entry := range entries {
		if !strings.HasPrefix(entry.Name(), "deck_") || !strings.HasSuffix(entry.Name(), ".log") {
			continue
		}
		info, err := entry.Info()
		if err != nil {
			continue
		}
		if info.ModTime().Before(cutoff) {
			os.Remove(filepath.Join(l.logDir, entry.Name()))
		}
	}
}

func (l *Logger) log(level Level, format string, args ...interface{}) {
	if level < l.level {
		return
	}
	prefix := levelPrefix(level)
	msg := fmt.Sprintf(format, args...)
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	line := fmt.Sprintf("%s [%s] %s\n", timestamp, prefix, msg)

	l.mu.Lock()
	defer l.mu.Unlock()
	l.buffer = append(l.buffer, line...)
	if level >= ERROR {
		l.flush()
	}
}

func levelPrefix(l Level) string {
	switch l {
	case DEBUG:
		return "DEBUG"
	case INFO:
		return "INFO "
	case WARNING:
		return "WARN "
	case ERROR:
		return "ERROR"
	default:
		return "?????"
	}
}

func (l *Logger) Debug(format string, args ...interface{}) { l.log(DEBUG, format, args...) }
func (l *Logger) Info(format string, args ...interface{})  { l.log(INFO, format, args...) }
func (l *Logger) Warn(format string, args ...interface{})  { l.log(WARNING, format, args...) }
func (l *Logger) Error(format string, args ...interface{}) { l.log(ERROR, format, args...) }

func Debug(format string, args ...interface{}) { Default().Debug(format, args...) }
func Info(format string, args ...interface{})  { Default().Info(format, args...) }
func Warn(format string, args ...interface{})  { Default().Warn(format, args...) }
func Error(format string, args ...interface{}) { Default().Error(format, args...) }
