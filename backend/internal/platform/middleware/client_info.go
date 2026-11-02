package middleware

import (
	"net/http"
	"strings"

	"github.com/gofiber/fiber/v3"

	"moneytracker/internal/platform/httpx"
)

const (
	headerDeviceID   = "X-Device-ID"
	headerPlatform   = "X-Platform"
	headerAppVersion = "X-App-Version"
	headerDeviceName = "X-Device-Name"

	platformAndroid = "android"
	platformIOS     = "ios"

	maxDeviceIDLen   = 64
	maxDeviceNameLen = 100
)

// ClientInfo validates the app identity headers (docs/API.md §1), stores them in locals,
// and rejects app versions older than the configured minimum with 426 upgrade_required.
// Missing or malformed headers are a 422 validation error listing the offending headers.
func ClientInfo(minAndroid, minIOS string) fiber.Handler {
	minVersions := map[string]semver{}
	if v, ok := parseSemver(minAndroid); ok {
		minVersions[platformAndroid] = v
	}
	if v, ok := parseSemver(minIOS); ok {
		minVersions[platformIOS] = v
	}

	return func(c fiber.Ctx) error {
		deviceID := strings.TrimSpace(c.Get(headerDeviceID))
		platform := strings.ToLower(strings.TrimSpace(c.Get(headerPlatform)))
		appVersion := strings.TrimSpace(c.Get(headerAppVersion))

		var fields []httpx.FieldError
		if deviceID == "" || len(deviceID) > maxDeviceIDLen {
			fields = append(fields, httpx.FieldError{Field: headerDeviceID, Message: "wajib diisi, maksimal 64 karakter"})
		}
		if platform != platformAndroid && platform != platformIOS {
			fields = append(fields, httpx.FieldError{Field: headerPlatform, Message: "harus android atau ios"})
		}
		version, versionOK := parseSemver(appVersion)
		if !versionOK {
			fields = append(fields, httpx.FieldError{Field: headerAppVersion, Message: "harus berformat MAJOR.MINOR.PATCH"})
		}
		if len(fields) > 0 {
			return httpx.Validation("Header identitas client tidak valid", fields...)
		}

		if min, ok := minVersions[platform]; ok && version.less(min) {
			return httpx.New(http.StatusUpgradeRequired, httpx.CodeUpgradeRequired, "Versi aplikasi terlalu lama, silakan perbarui")
		}

		deviceName := strings.TrimSpace(c.Get(headerDeviceName))
		if len(deviceName) > maxDeviceNameLen {
			deviceName = deviceName[:maxDeviceNameLen]
		}
		c.Locals(httpx.LocalClientInfo, httpx.ClientInfo{
			DeviceID:   deviceID,
			Platform:   platform,
			AppVersion: appVersion,
			DeviceName: deviceName,
		})
		return c.Next()
	}
}
