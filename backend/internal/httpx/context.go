package httpx

import "context"

type contextKey string

const claimsKey contextKey = "claims"

func withClaims(ctx context.Context, c ClaimsIdentity) context.Context {
	return context.WithValue(ctx, claimsKey, c)
}

func claimsFromContext(ctx context.Context) (ClaimsIdentity, bool) {
	value := ctx.Value(claimsKey)
	c, ok := value.(ClaimsIdentity)
	return c, ok
}
