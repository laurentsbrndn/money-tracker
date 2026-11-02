package database

import (
	"context"
	"errors"
	"log/slog"
	"time"

	"gorm.io/gorm"
	gormlogger "gorm.io/gorm/logger"
)

const slowQueryThreshold = 300 * time.Millisecond

// gormLogger routes GORM logging to slog: warnings for slow queries, errors for failed ones.
type gormLogger struct {
	log *slog.Logger
}

func newGormLogger(log *slog.Logger) gormlogger.Interface {
	return &gormLogger{log: log}
}

// ParamsFilter drops bound values so logged SQL never contains user data.
func (l *gormLogger) ParamsFilter(_ context.Context, sql string, _ ...any) (string, []any) {
	return sql, nil
}

func (l *gormLogger) LogMode(gormlogger.LogLevel) gormlogger.Interface {
	return l
}

func (l *gormLogger) Info(ctx context.Context, msg string, args ...any) {
	l.log.InfoContext(ctx, msg, "args", args)
}

func (l *gormLogger) Warn(ctx context.Context, msg string, args ...any) {
	l.log.WarnContext(ctx, msg, "args", args)
}

func (l *gormLogger) Error(ctx context.Context, msg string, args ...any) {
	l.log.ErrorContext(ctx, msg, "args", args)
}

func (l *gormLogger) Trace(ctx context.Context, begin time.Time, fc func() (string, int64), err error) {
	elapsed := time.Since(begin)
	switch {
	case err != nil && !errors.Is(err, gorm.ErrRecordNotFound):
		sql, rows := fc()
		l.log.ErrorContext(ctx, "database query failed", "error", err, "elapsed_ms", elapsed.Milliseconds(), "rows", rows, "sql", sql)
	case elapsed > slowQueryThreshold:
		sql, rows := fc()
		l.log.WarnContext(ctx, "slow database query", "elapsed_ms", elapsed.Milliseconds(), "rows", rows, "sql", sql)
	}
}
