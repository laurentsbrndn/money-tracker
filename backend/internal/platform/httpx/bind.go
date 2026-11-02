package httpx

import (
	"encoding/json"
	"errors"
	"fmt"
	"reflect"
	"strings"

	"github.com/go-playground/validator/v10"
	"github.com/gofiber/fiber/v3"
)

// validate is stateless apart from an internal struct cache, so one shared instance is safe.
var validate = newValidator()

func newValidator() *validator.Validate {
	v := validator.New(validator.WithRequiredStructEnabled())
	v.RegisterTagNameFunc(func(f reflect.StructField) string {
		name := strings.SplitN(f.Tag.Get("json"), ",", 2)[0]
		if name == "-" || name == "" {
			return f.Name
		}
		return name
	})
	return v
}

// BindAndValidate decodes the JSON request body into T and validates it with `validate` tags.
// Failures are returned as a 422 validation AppError.
func BindAndValidate[T any](c fiber.Ctx) (T, error) {
	var dst T
	if err := json.Unmarshal(c.Body(), &dst); err != nil {
		return dst, Validation("Body bukan JSON yang valid")
	}
	if err := validate.Struct(dst); err != nil {
		return dst, validationFromError(err)
	}
	return dst, nil
}

func validationFromError(err error) *AppError {
	var verrs validator.ValidationErrors
	if !errors.As(err, &verrs) {
		return Validation("Request tidak valid")
	}
	fields := make([]FieldError, 0, len(verrs))
	for _, fe := range verrs {
		fields = append(fields, FieldError{Field: fe.Namespace()[strings.Index(fe.Namespace(), ".")+1:], Message: fieldMessage(fe)})
	}
	return Validation("Beberapa field tidak valid", fields...)
}

func fieldMessage(fe validator.FieldError) string {
	switch fe.Tag() {
	case "required":
		return "wajib diisi"
	case "email":
		return "format email tidak valid"
	case "min":
		return fmt.Sprintf("minimal %s", fe.Param())
	case "max":
		return fmt.Sprintf("maksimal %s", fe.Param())
	case "len":
		return fmt.Sprintf("harus tepat %s", fe.Param())
	case "oneof":
		return fmt.Sprintf("harus salah satu dari: %s", fe.Param())
	default:
		return "tidak valid"
	}
}
