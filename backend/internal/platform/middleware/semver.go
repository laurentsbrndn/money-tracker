package middleware

import (
	"strconv"
	"strings"
)

// semver is a MAJOR.MINOR.PATCH version. Pre-release and build suffixes are ignored.
type semver [3]int

// parseSemver reads "MAJOR.MINOR.PATCH" (an optional -pre or +build suffix is dropped).
func parseSemver(s string) (semver, bool) {
	if i := strings.IndexAny(s, "-+"); i >= 0 {
		s = s[:i]
	}
	parts := strings.Split(s, ".")
	if len(parts) != 3 {
		return semver{}, false
	}
	var v semver
	for i, p := range parts {
		if p == "" {
			return semver{}, false
		}
		n, err := strconv.Atoi(p)
		if err != nil || n < 0 {
			return semver{}, false
		}
		v[i] = n
	}
	return v, true
}

// less reports whether v is an older version than o.
func (v semver) less(o semver) bool {
	for i := range v {
		if v[i] != o[i] {
			return v[i] < o[i]
		}
	}
	return false
}
